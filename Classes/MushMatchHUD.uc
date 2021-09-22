class MushMatchHUD extends ChallengeHUD;

#exec texture import name=MMHUDMush group=HUD file=Textures\HudMush.pcx
#exec texture import name=MMHUDHuman group=HUD file=Textures\HudHuman.pcx
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
    
    if ( MushMatchInfo(PlayerOwner.GameReplicationInfo).bMushSelected && !MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bDead )
    {
        Drawer.DrawColor = HUDColor * 0.75;
        Drawer.SetPos(Drawer.SizeX * 0.475, 0);
        
        if ( PlayerOwner.PlayerReplicationInfo.Team == 0 )
            Drawer.DrawIcon(Texture'MMHUDHuman', Drawer.SizeX * 0.05 / 128);
            
        else
            Drawer.DrawIcon(Texture'MMHUDMush', Drawer.SizeX * 0.05 / 128);
        
        Drawer.SetPos(Drawer.SizeX * 0.475, Drawer.SizeX * 0.05);
        
        if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bKnownMush )
            Drawer.DrawIcon(Texture'MMHUDKnownMush', Drawer.SizeX * 0.05 / 128);
        
        else if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bKnownHuman )
            Drawer.DrawIcon(Texture'MMHUDKnownHuman', Drawer.SizeX * 0.05 / 128);
        
        else if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bIsSuspected )
            Drawer.DrawIcon(Texture'MMHUDSuspected', Drawer.SizeX * 0.05 / 128);
            
        Drawer.DrawColor = WhiteColor;
    }
}

simulated event bool DrawIdentifyInfo(canvas Canvas)
{
    local MushMatchPRL myPRL;

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
        
        if ( TeamText(IdentifyTarget) != "" ) {
            DrawTwoColorID(Canvas, "Status", TeamTextStatus(IdentifyTarget), Canvas.ClipY - 216 * Scale);   
            DrawTwoColorID(Canvas, "Alignment", TeamTextAlignment(IdentifyTarget), Canvas.ClipY - 192 * Scale);
        }
    }
    
    return true;
}

defaultproperties
{
}