class MushMatchHUD extends ChallengeHUD;

#exec texture import name=MMHUDMush group=HUD file=Textures\HudMush.pcx
#exec texture import name=MMHUDHuman group=HUD file=Textures\HudHuman.pcx
#exec texture import name=MMHUDHumanNoimmune group=HUD file=Textures\HudHumanNoimmune.pcx
#exec texture import name=MMHUDKnownMush group=HUD file=Textures\HudKnownM.pcx
#exec texture import name=MMHUDKnownHuman group=HUD file=Textures\HudKnownH.pcx
#exec texture import name=MMHUDSuspected group=HUD file=Textures\HudSuspected.pcx



simulated event string TeamText(PlayerReplicationInfo PRI)
{
    return MushMatchInfo(PlayerOwner.GameReplicationInfo).TeamText(PRI, PlayerOwner);
}

simulated event string TeamTextStatus(PlayerReplicationInfo PRI)
{
    return MushMatchInfo(PlayerOwner.GameReplicationInfo).TeamTextStatus(PRI, PlayerOwner);
}

simulated event string TeamTextAlignment(PlayerReplicationInfo PRI)
{
    return MushMatchInfo(PlayerOwner.GameReplicationInfo).TeamTextAlignment(PRI, PlayerOwner);
}

simulated event PostRender(Canvas Drawer)
{
    local MushMatchPRL PlayerPRL;
    local float FlatSize, ImmuneShow;

    Super.PostRender(Drawer);

    if (MushMatchInfo(PlayerOwner.GameReplicationInfo) == None) {
        // wait for replication
        return;
    }

    if (MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL == None) {
        // wait for PRL replication
        return;
    }

    if ( PlayerOwner == None ) {
        Warn("PlayerOwner is none!");
        return;
    }

    if ( !PlayerOwner.bIsPlayer ) {
        Warn("PlayerOwner"@ PlayerOwner @"is not a player!");
        return;
    }

    if ( PlayerOwner.PlayerReplicationInfo == None ) {
        if (MushMatchInfo(PlayerOwner.GameReplicationInfo).bMatchStart) {
            Warn("PlayerOwner"@ PlayerOwner @"lacks a PlayerReplicationInfo!");
        }
        return;
    }

    if ( MushMatchInfo(PlayerOwner.GameReplicationInfo) == None ) {
        Warn("PlayerOwner lacks a MushMatch GameReplicationInfo!");
        return;
    }

    if ( MushMatchInfo(PlayerOwner.GameReplicationInfo).bMatchEnd || PlayerOwner.IsInState('Dying') ) {
        return;
    }

    PlayerPRL = MushMatchInfo(PlayerOwner.GameReplicationInfo).FindPRL(PlayerOwner.PlayerReplicationInfo);

    if ( MushMatchInfo(PlayerOwner.GameReplicationInfo).bMushSelected && !PlayerPRL.bDead )
    {
        FlatSize = Drawer.SizeX * 0.05 / 128;
        Drawer.DrawColor = HUDColor * 0.75;
        Drawer.SetPos(Drawer.SizeX * 0.475, 0);

        if (!PlayerPRL.bMush) {
            Drawer.DrawIcon(Texture'MMHUDHuman', FlatSize);

            if (PlayerPRL.ImmuneLevel < 1) {
                ImmuneShow = (1.0 - Max(0, PlayerPRL.ImmuneLevel)) * FlatSize;
                Drawer.SetPos(Drawer.CurX + 4, Drawer.CurY + 4);
                Drawer.DrawTile(Texture'MMHUDHumanNoimmune', FlatSize - 8, ImmuneShow - 8, 0, 0, FlatSize - 8, ImmuneShow - 8);
                Drawer.SetPos(Drawer.CurX - 4, Drawer.CurY - 4);
            }
        }

        else
            Drawer.DrawIcon(Texture'MMHUDMush', FlatSize);

        Drawer.SetPos(Drawer.SizeX * 0.475, Drawer.SizeX * 0.05);

        if ( PlayerPRL.bKnownMush )
            Drawer.DrawIcon(Texture'MMHUDKnownMush', FlatSize);

        else if ( PlayerPRL.bKnownHuman )
            Drawer.DrawIcon(Texture'MMHUDKnownHuman', FlatSize);

        else if ( PlayerPRL.bIsSuspected )
            Drawer.DrawIcon(Texture'MMHUDSuspected', FlatSize);

        Drawer.DrawColor = WhiteColor;
    }
}

simulated event bool DrawIdentifyInfo(canvas Canvas)
{
    local MushMatchPRL myPRL, targPRL;

    if (MushMatchInfo(PlayerOwner.GameReplicationInfo) == None) {
        // wait for replication
        return false;
    }

    if (MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL == None) {
        // wait for PRL replication
        return false;
    }

    myPRL = MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo));

    if (myPRL == None) {
        Warn("No PRL found for player: "@ PlayerOwner @ PlayerOwner.PlayerReplicationInfo.PlayerName @ MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL);
        return false;
    }

    if ( !TraceIdentify(Canvas) )
        return false;

    if( IdentifyTarget != None && IdentifyTarget.PlayerName != "" )
    {
        Canvas.DrawColor = WhiteColor;
        Canvas.Font = MyFonts.GetBigFont(Canvas.ClipX);
        DrawTwoColorID(Canvas, IdentifyName, IdentifyTarget.PlayerName, Canvas.ClipY - 256 * Scale);

        targPRL = MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(IdentifyTarget));

        if (targPRL == None) {
            return true;
        }

        if ( TeamText(IdentifyTarget) == "" ) {
            return true;
        }

        DrawTwoColorID(Canvas, "Status", TeamTextStatus(IdentifyTarget), Canvas.ClipY - 216 * Scale);
        DrawTwoColorID(Canvas, "Alignment", TeamTextAlignment(IdentifyTarget), Canvas.ClipY - 192 * Scale);

        if ((myPRL.bMush && targPRL.bMush) || myPRL.bDead) {
            DrawTwoColorID(Canvas, "Health", String(Pawn(IdentifyTarget.Owner).Health), Canvas.ClipY - 168 * Scale);
        }
    }

    return true;
}

defaultproperties
{
}
