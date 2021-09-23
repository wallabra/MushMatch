class MushMatchMutator extends DMMutator;


var(MushMatch) config float ScreamRadius, DirectionBlameRadius;

var PlayerPawn PlayerOwner;


replication {
    unreliable if (Role == ROLE_Authority)
        ScreamRadius, DirectionBlameRadius;
}


var bool bBeginplayed;

function PostBeginPlay() {
    if ( bBeginplayed )
        return;

    Super.PostBeginPlay();

    if (Role == ROLE_Authority) {
        Level.Game.RegisterDamageMutator(self);
    }

    bBeginplayed = true;
}

simulated function Tick(float TimeDelta) {
    Super.Tick(TimeDelta);

    if (!bHUDMutator && Level.NetMode != NM_DedicatedServer) {
        Log("Consider registering MushMatchMutator as HUD in the clientside");

        if (FindLocalPlayer()) {
            Log("Local player found, register MushMatchMutator as HUD mutator");
            RegisterHUDMutator();
        }

        else {
            Warn("Clientside MushMatchMutator found but no local player!");
        }
    }
}

simulated function bool FindLocalPlayer() {
    if (Level.NetMode == NM_DedicatedServer) {
        return false; // server-side
    }

    if (PlayerOwner == None) {
        foreach AllActors(class'PlayerPawn', PlayerOwner) {
            if (Viewport(PlayerOwner.Player) != None) {
                return true;
            }
        }

        PlayerOwner = None; // in fact other PlayerPawns were found but not our own... odd

        Warn("Local player not found for HUD logic of"@ self);
        return false;
    }

    return true;
}

function bool HandleEndGame()
{
    return true;
}

simulated event MutatorTakeDamage(out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
    if ( InstigatedBy == None || Victim == None || InstigatedBy == Victim )
        return;

    if ( MushMatch(Level.Game).bMushSelected  )
    {
        if ( !MushMatchInfo(Level.Game.GameReplicationInfo).CheckBeacon(Victim.PlayerReplicationInfo) )
            CheckSuspects(InstigatedBy, Victim);
    }

    else
        Victim.Health = 100;

    if ( NextDamageMutator != None )
        NextDamageMutator.MutatorTakeDamage(ActualDamage, Victim, InstigatedBy, HitLocation, Momentum, DamageType);
}

simulated event ModifyPlayer(Pawn Other)
{
    local Weapon w;

    w = Other.Weapon;
    Other.Spawn(class'MushBeacon').GiveTo(Other);

    if (Other.PlayerReplicationInfo.Team == 1 && MushMatch(Level.Game).bMushSelected) {
        Other.Spawn(class'Sporifier').GiveTo(Other);
    }

    if ( w != None ) Other.Weapon = w;

    if ( NextMutator != None )
        NextMutator.ModifyPlayer(Other);
}

function bool WitnessSuspect(Pawn Victim, Pawn InstigatedBy, Pawn Witness) {
    local MushMatchPRL WitPRL;

    // sanity checks

    if (!Witness.bIsPlayer) {
        return false;
    }

    if (Witness.PlayerReplicationInfo == None) {
        return false;
    }

    if (Witness.IsInState('Dying')) {
        return false;
    }

    if (Witness == InstigatedBy) {
        return false;
    }

    WitPRL = MushMatchInfo(Level.Game.GameReplicationInfo).FindPRL(Witness.PlayerReplicationInfo);

    if (WitPRL.bDead) {
        return false;
    }

    // now the interesting checks

    if (!Witness.LineOfSightTo(Victim)) {
        return false;
    }

    if (!Witness.CanSee(InstigatedBy)) {
        // other witness check
        if (Witness != Victim) {
            // scream alerting
            if (VSize(InstigatedBy.Location - Witness.Location) > ScreamRadius || FRand() < 0.35) {
                return false;
            }
        }

        // victim's own check
        if (Witness == Victim) {
            // know direction of your own hit, use to blame
            if (VSize(InstigatedBy.Location - Victim.Location) > DirectionBlameRadius || FRand() < 0.7) {
                return false;
            }
        }
    }

    // make sure this suspicion does not already exist

    if (MushMatch(Level.Game).bHasHate && MushMatchInfo(Level.Game.GameReplicationInfo).CheckHate(InstigatedBy.PlayerReplicationInfo, Witness.PlayerReplicationInfo)) {
        return false;
    }

    // raise an eyebrow!

    return true;
}

function CheckSuspects(Pawn InstigatedBy, Pawn Victim)
{
    local Pawn P;
    local bool bEligible;
    local MushMatchInfo MMI;

    if (InstigatedBy.PlayerReplicationInfo == None)
        return;

    if (Victim.PlayerReplicationInfo == None)
        return;

    MMI = MushMatchInfo(Level.Game.GameReplicationInfo);

    if (MMI == None)
        return;

    if ( MushMatchPRL(MMI.PRL.FindPlayer(InstigatedBy.PlayerReplicationInfo)) == None ) {
        return;
    }

    bEligible = (Victim.PlayerReplicationInfo.Team == 0 && !MMI.CheckConfirmedHuman(InstigatedBy.PlayerReplicationInfo));

    if ( /* suspicion */ bEligible || /* subversion */ Victim.PlayerReplicationInfo.Team == 1 )
    {
        for ( P = Level.PawnList; P != None; P = P.NextPawn )
            if (WitnessSuspect(Victim, InstigatedBy, P)) {
                // Log(p.PlayerReplicationInfo.PlayerName@"suspects"@InstigatedBy.PlayerReplicationInfo.PlayerName);

                // complete bEligible for P
                if (!(/* suspicion */  (P.PlayerReplicationInfo.Team == 0 && !MMI.CheckConfirmedHuman(InstigatedBy.PlayerReplicationInfo)) ||
                      /* subversion */ (P.PlayerReplicationInfo.Team == 1 && InstigatedBy.PlayerReplicationInfo.Team == 0))) {
                    return;
                }

                MushMatch(Level.Game).RegisterHate(P, InstigatedBy);
            }

        if (WitnessSuspect(Victim, InstigatedBy, Victim)) {
            // Log(Victim.PlayerReplicationInfo.PlayerName@"suspects"@InstigatedBy.PlayerReplicationInfo.PlayerName);

            // complete bEligible for Victim
            if (!(/* suspicion */ (Victim.PlayerReplicationInfo.Team == 0 && !MMI.CheckConfirmedHuman(InstigatedBy.PlayerReplicationInfo)) ||
                  /* subversion */ Victim.PlayerReplicationInfo.Team == 1 && InstigatedBy.PlayerReplicationInfo.Team == 0)) {
                return;
            }

            MushMatch(Level.Game).RegisterHate(Victim, InstigatedBy);
        }
    }
}

/*
function DeprecatedTellTeam(byte PTeam, string PName, optional bool bAutopsy)
{
    if ( bAutopsy )
    {
        if ( PTeam == 0 )
            Broadcastmessage(PName@"was found dead! Autopsy revealed he/she was a human!", true, 'CriticalEvent');

        else
            Broadcastmessage(PName@"was found dead! Autopsy revealed it was a mush!", true, 'CriticalEvent');
    }

    else
    {
        if ( PTeam == 0 )
            Broadcastmessage(PName@"was found dead! Gib scan revealed the identity and that... he/she was a human!", true, 'CriticalEvent');

        else
            Broadcastmessage(PName@"was found dead! Gib scan revealed the identity and that... it was a mush!", true, 'CriticalEvent');
    }
}

function TellTeam(byte PTeam, string PName, string Pronoun, string PronounCaps)
{
    if ( PTeam == 0 )
        Broadcastmessage(PName @"died and is now out of the game!"@ PronounCaps @"was a human!", true, 'CriticalEvent');

    else
        Broadcastmessage(PName @"died and is now out of the game! It was a mush!", true, 'CriticalEvent');
}
*/

/* -- handled in Mush___Message classes
    function string GetPronounFor(PlayerReplicationInfo Other) {
        if (Other.bIsFemale)
            return "she";

        else
            return "he";
    }

    function string GetCapsPronounFor(PlayerReplicationInfo Other) {
        if (Other.bIsFemale)
            return "She";

        else
            return "He";
    }
*/

simulated function MutatorScoreKill(Pawn Killer, Pawn Other, optional bool bTell)
{
    local bool b;
    local Pawn P;
    local MushMatchInfo MMI;
    local MushMatchPRL KPRL;

    MMI = MushMatchInfo(Level.Game.GameReplicationInfo);

    if (MMI == None)
        return;

    if (Killer == None)
        return;

    KPRL = MushMatchPRL(MushMatchInfo(Level.Game.GameReplicationInfo).PRL.FindPlayer(Killer.PlayerReplicationInfo));

    if (KPRL == None || KPRL.bDead)
        return;

    if ( Other.PlayerReplicationInfo.Team == 1 && !MMI.CheckConfirmedMush(Killer.PlayerReplicationInfo) )
        for ( P = Level.PawnList; P != None; P = P.NextPawn )
            if ( P.bIsPlayer && P.CanSee(Killer) && P.PlayerReplicationInfo.Team == 0 && P != Killer && !MMI.CheckBeacon(P.PlayerReplicationInfo) ) {
                KPRL.RemoveHate(P.PlayerReplicationInfo);
                KPRL.bIsSuspected = False;
                b = true;
                break;
            }

    if (b) {
        //MushMatch(Level.Game).BroadcastMessage(Killer.PlayerReplicationInfo.PlayerName$" had their suspicions lifted after being witnessed killing a mush,"@Other.PlayerReplicationInfo.PlayerName$"!", true, 'CriticalEvent');
        MushMatch(Level.Game).BroadcastUnsuspected(Killer.PlayerReplicationInfo, Other.PlayerReplicationInfo);
    }

    if (MushMatch(Level.Game).bMushSelected && !MMI.CheckBeacon(Other.PlayerReplicationInfo)) {
        if (Role == ROLE_Authority) {
            if (!MMI.CheckConfirmedMush(Killer.PlayerReplicationInfo) && !b) CheckSuspects(Killer, Other);
        }
    }
}

//===== HUD Drawing for Modding Compatibility ========//
/*
 * Used e.g. when playing with NewNet.
 */

simulated function PostRender(Canvas Drawer) {
    if (Level.NetMode != NM_DedicatedServer) {
        HUD_PostRender(Drawer);
    }

    if (NextHUDMutator != None) {
        NextHUDMutator.PostRender(Drawer);
    }
}

simulated function HUD_PostRender(Canvas Drawer) {
    local ChallengeHUD CHUD;

    if (PlayerOwner == None) {
        return;
    }

    CHUD = ChallengeHUD(PlayerOwner.MyHUD);

    if (CHUD == None) {
        return;
    }

    // maybe find identify target
    if (CHUD.IdentifyFadeTime > 0.0 && CHUD.IdentifyTarget != None && CHUD.IdentifyTarget.PlayerName != "") {
        HUD_DrawSpecialIdentifyInfo(Drawer,
            CHUD.IdentifyTarget,
            CHUD
        );
    }

    // draw special game status
    HUD_DrawGameStatus(Drawer, CHUD);
}

simulated function string TeamText(PlayerReplicationInfo PRI)
{
    return MushMatchInfo(PlayerOwner.GameReplicationInfo).TeamText(PRI, PlayerOwner);
}

simulated function string TeamTextStatus(PlayerReplicationInfo PRI)
{
    return MushMatchInfo(PlayerOwner.GameReplicationInfo).TeamTextStatus(PRI, PlayerOwner);
}

simulated function string TeamTextAlignment(PlayerReplicationInfo PRI)
{
    return MushMatchInfo(PlayerOwner.GameReplicationInfo).TeamTextAlignment(PRI, PlayerOwner);
}

simulated function HUD_DrawGameStatus(Canvas Drawer, ChallengeHUD BaseHUD)
{
    local MushMatchPRL PlayerPRL;
    local float FlatSize, ImmuneShow;
    //Super.PostRender(Drawer);

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

        Drawer.DrawColor = BaseHUD.HUDColor * 0.75;
        Drawer.SetPos(Drawer.SizeX * 0.475, 0);

        if ( PlayerOwner.PlayerReplicationInfo.Team == 0 ) {
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

        if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bKnownMush )
            Drawer.DrawIcon(Texture'MMHUDKnownMush', FlatSize);

        else if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bKnownHuman )
            Drawer.DrawIcon(Texture'MMHUDKnownHuman', FlatSize);

        else if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bIsSuspected )
            Drawer.DrawIcon(Texture'MMHUDSuspected', FlatSize);

        //Drawer.DrawColor = BaseHUD.WhiteColor;
    }
}

simulated function bool HUD_DrawSpecialIdentifyInfo(Canvas Drawer, PlayerReplicationInfo IdentifyTarget, ChallengeHUD BaseHUD)
{
    local MushMatchPRL myPRL, otherPRL;
    local int Linefeed;

    /*
    if (MushMatchInfo(PlayerOwner.GameReplicationInfo) == None) {
        // wait for replication
        return false;
    }

    if (MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL == None) {
        // wait for PRL replication
        return false;
    }
    */

    BaseHUD.HUDSetup(Drawer);

    // Skip usual circumstances where identity info is not drawn
    if (
        BaseHUD.bShowInfo ||
        BaseHUD.PlayerOwner.bShowScores ||
        BaseHUD.bForceScores ||
        BaseHUD.bHideCenterMessages ||
        BaseHUD.bHideHUD ||
        BaseHUD.PawnOwner != BaseHUD.PlayerOwner
    ) {
        return false;
    }

    myPRL = MushMatchInfo(PlayerOwner.GameReplicationInfo).FindPRL(PlayerOwner.PlayerReplicationInfo);

    if (myPRL == None) {
        Warn("No PRL found for player: "@ PlayerOwner @ PlayerOwner.PlayerReplicationInfo.PlayerName @ MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL);
        return false;
    }

    otherPRL = MushMatchInfo(PlayerOwner.GameReplicationInfo).FindPRL(IdentifyTarget);

    if( IdentifyTarget != None && IdentifyTarget.PlayerName != "" )
    {
        Drawer.Style = ERenderStyle.STY_Translucent;
        Drawer.DrawColor = BaseHUD.GreenColor;

        Linefeed = 40;

        if ( TeamText(IdentifyTarget) != "" ) {
            BaseHUD.DrawTwoColorID(Drawer, "Status", TeamTextStatus(IdentifyTarget), Drawer.ClipY - (256 - Linefeed) * BaseHUD.Scale);
            Linefeed += 24;
            BaseHUD.DrawTwoColorID(Drawer, "Alignment", TeamTextAlignment(IdentifyTarget), Drawer.ClipY - (256 - Linefeed) * BaseHUD.Scale);
            Linefeed += 24;

            if (PlayerOwner.PlayerReplicationInfo.Team == 1 && IdentifyTarget.Team == 0) {
                if (OtherPRL.ImmuneLevel <= OtherPRL.ImmuneDangerLevel) {
                    Drawer.DrawColor = BaseHUD.RedColor;
                }

                // Display immune level (maybe temporary debug?)
                BaseHUD.DrawTwoColorID(Drawer,
                                       "Immune",
                                       Int(100 * OtherPRL.ImmuneLevel) $"%",
                                       Drawer.ClipY - (256 - Linefeed) * BaseHUD.Scale
                );
                Linefeed += 24;

                Drawer.DrawColor = BaseHUD.GreenColor;
            }
        }
    }

    return true;
}


defaultproperties
{
    ScreamRadius=300
    DirectionBlameRadius=400
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
    bNetTemporary=True
}
