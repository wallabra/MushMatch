class MushMatchMutator extends DMMutator config(MushMatch);


var(MushMatch) config float ScreamRadius, DirectionBlameRadius, MinGuaranteeSuspectDamage, VictimSuspectChance, ScreamSuspectChance, NameClearChanceNormal, NameClearChanceBothMush, SuspectHuntOverlookKillChance, SuspectHuntOverlookDamageChance, OverlookChanceFactorTargetIsSuspect;

var PlayerPawn PlayerOwner;


replication {
    unreliable if (Role == ROLE_Authority)
        ScreamRadius, DirectionBlameRadius;
}


var bool bBeginplayed;

function bool IsRelevant(Actor Other, out byte bSuperRelevant)
{
    if ( Sporifier(Other) != None || SporeCanister(Other) != None || MushBeacon(Other) != None || MushBeaconAmmo(Other) != None )
        return true;

    return Super.IsRelevant(Other, bSuperRelevant);
}

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

        if (FindLocalPlayer() != None) {
            Log("Local player found, register MushMatchMutator as HUD mutator");
            RegisterHUDMutator();
        }

        else {
            Warn("Clientside MushMatchMutator found but no local player!");
        }
    }
}

simulated function PlayerPawn FindLocalPlayer() {
    if (Level.NetMode == NM_DedicatedServer) {
        return None; // server-side
    }

    if (PlayerOwner == None) {
        foreach AllActors(class'PlayerPawn', PlayerOwner) {
            if (Viewport(PlayerOwner.Player) != None) {
                return PlayerOwner;
            }
        }

        PlayerOwner = None; // in fact other PlayerPawns were found but not our own... odd

        Warn("Local player not found for HUD logic of"@ self);
        return None;
    }

    return PlayerOwner;
}

function bool HandleEndGame()
{
    return true;
}

simulated event MutatorTakeDamage(out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
    local MushMatchInfo MMI;
    local float OverlookChance;

    MMI = MushMatchInfo(Level.Game.GameReplicationInfo);

    // Let other mutators process the damage before we decide upon it ourselves
    if ( NextDamageMutator != None ) {
        NextDamageMutator.MutatorTakeDamage(ActualDamage, Victim, InstigatedBy, HitLocation, Momentum, DamageType);
    }

    if ( InstigatedBy == None || Victim == None || InstigatedBy == Victim || MMI == None ) {
        return;
    }

    if (Role == ROLE_Authority && MushMatch(Level.Game).bMushSelected) {
        // If already has suspicion beacon, skip; otherwise it would be redundant
        if ( MushMatchInfo(Level.Game.GameReplicationInfo).CheckBeacon(Victim.PlayerReplicationInfo) ) {
            return;
        }

        // Cull small damage events, like falling over top of someone's head, but with a linear probability
        if (ActualDamage < MinGuaranteeSuspectDamage && FRand() * MinGuaranteeSuspectDamage > ActualDamage) {
            return;
        }

        // Add chance.
        OverlookChance = SuspectHuntOverlookDamageChance;

        if (MMI.CheckBeacon(Victim.PlayerReplicationInfo)) {
            // Damaging someone who is suspected is less bad!
            OverlookChance += (1.0 - OverlookChance) * OverlookChanceFactorTargetIsSuspect;
        }

        if (FRand() < OverlookChance) {
            return;
        }
        
        // See if anyone saw that!
        CheckSuspects(InstigatedBy, Victim);
    }

    else {
        Victim.Health = 100;
    }
}

simulated function MushMatchPRL FindPawnPRL(Pawn Other) {
    if (Other == None) return None;
    if (Other.PlayerReplicationInfo == None) return None;

    if (Role == ROLE_Authority) {
        return MushMatchInfo(Level.Game.GameReplicationInfo).FindPRL(Other.PlayerReplicationInfo);
    }

    else {
        return MushMatchInfo(FindLocalPlayer().GameReplicationInfo).FindPRL(Other.PlayerReplicationInfo);
    }
}

simulated event ModifyPlayer(Pawn Other) {
    local Weapon w;
    local MushMatchPRL MPRL;

    w = Other.Weapon;
    Other.Spawn(class'MushBeacon').GiveTo(Other);

    // Give a Sporifier IF the match has already started and the player added is in the mush team
    if (Role == ROLE_Authority && MushMatch(Level.Game).bMushSelected) {
        MPRL = FindPawnPRL(Other);

        if (MPRL == None) {
            Warn("Tried to call MushMatchMutator.ModifyPlayer on a Pawn"@ Other @"with no associated MushMatchPRL during a started match");
            return;
        }

        if (MPRL.bMush) {
            Other.Spawn(class'Sporifier').GiveTo(Other);
        }
    }

    if (w != None) {
        Other.Weapon = w;
    }

    if (NextMutator != None) {
        NextMutator.ModifyPlayer(Other);
    }
}

function bool WitnessSuspect(Pawn Victim, Pawn InstigatedBy, Pawn Witness) {
    local MushMatchPRL WitPRL, VictPRL, InstigPRL;

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

    // (only bots count!)
    if (PlayerPawn(Witness) != None) {
        return false;
    }

    WitPRL = FindPawnPRL(Victim);
    InstigPRL = FindPawnPRL(InstigatedBy);
    VictPRL = FindPawnPRL(Witness);

    if (WitPRL == None || InstigPRL == None || VictPRL == None) {
        return false;
    }

    if (WitPRL.bDead) {
        return false;
    }

    // now the interesting checks

    if (WitPRL.bMush && VictPRL.bMush) {
        return false;
    }

    if (WitPRL.bKnownMush) {
        return false;
    }

    if (!Witness.LineOfSightTo(Victim)) {
        return false;
    }

    if (!Witness.CanSee(InstigatedBy)) {
        // other witness check
        if (Witness != Victim) {
            // scream alerting
            if (VSize(InstigatedBy.Location - Witness.Location) > ScreamRadius || FRand() < ScreamSuspectChance) {
                return false;
            }
        }

        // victim's own check
        else {
            // know direction of your own hit, use to blame
            if (VSize(InstigatedBy.Location - Victim.Location) > DirectionBlameRadius || FRand() < VictimSuspectChance) {
                return false;
            }
        }
    }

    // make sure this suspicion does not already exist

    if (MushMatch(Level.Game).bHasHate && !MushMatchInfo(Level.Game.GameReplicationInfo).CheckHate(InstigatedBy.PlayerReplicationInfo, Witness.PlayerReplicationInfo)) {
        return false;
    }

    // raise an eyebrow!
    return true;
}

function CheckSuspects(Pawn InstigatedBy, Pawn Victim)
{
    local Pawn P;
    local MushMatchInfo MMI;
    local MushMatchPRL VictimPRL, InstigatorPRL;

    if (InstigatedBy.PlayerReplicationInfo == None) {
        return;
    }

    if (Victim.PlayerReplicationInfo == None) {
        return;
    }

    MMI = MushMatchInfo(Level.Game.GameReplicationInfo);

    if (MMI == None) {
        return;
    }

    VictimPRL = FindPawnPRL(Victim);
    InstigatorPRL = FindPawnPRL(InstigatedBy);

    if (VictimPRL == None || InstigatorPRL == None) {
        return;
    }

    if (VictimPRL.bMush && InstigatorPRL.bMush) {
        return;
    }

    if (VictimPRL.bKnownMush) {
        return;
    }

    if (InstigatorPRL.bKnownMush) {
        return;
    }

    if (InstigatorPRL.bKnownHuman) {
        // can't suspect, only spot!
        return;
    }

    // Check for witnesses and suspicions.

    for (P = Level.PawnList; P != None; P = P.NextPawn) {
        if (!WitnessSuspect(Victim, InstigatedBy, P)) {
            continue;
        }

        MushMatch(Level.Game).RegisterHate(P, InstigatedBy);
    }

    if (WitnessSuspect(Victim, InstigatedBy, Victim)) {
        MushMatch(Level.Game).RegisterHate(Victim, InstigatedBy);
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

simulated function MushMatchCheckKill(Pawn Killer, Pawn Other, optional bool bTell)
{
    local bool bNameCleared;
    local Pawn P;
    local MushMatchInfo MMI;
    local MushMatchPRL OPRL, KPRL, PPRL;
    local float NameClearIgnoreChance, SuspectOverlookChance;

    if (Role != ROLE_Authority) {
        return;
    }

    MMI = MushMatchInfo(Level.Game.GameReplicationInfo);

    if (MMI == None)
        return;

    if (Killer == None)
        return;

    KPRL = FindPawnPRL(Killer);
    OPRL = FindPawnPRL(Other);

    if (OPRL == None || KPRL == None || KPRL.bDead)
        return;

    if (OPRL.bMush && !MMI.CheckConfirmedMush(Killer.PlayerReplicationInfo) && MMI.CheckBeacon(Killer.PlayerReplicationInfo)) {
        for (P = Level.PawnList; P != None; P = P.NextPawn) {
            // Ensure they're not the killer themself
            if (P == Killer) continue;

            // Ensure they are a member of the match
            if (!P.bIsPlayer) {
                continue;
            }

            // Ensure they have a MushMatchPRL
            PPRL = FindPawnPRL(P);

            if (PPRL == None) {
                continue;
            }

            // Ensure they could see what happened
            if (!P.CanSee(Killer)) {
                continue;
            }

            // Ensure they have a clean record (irrespective of whether they are a mush in reality)
            if (PPRL.bIsSuspected || PPRL.bKnownMush) {
                continue;
            }

            // They may not have bothered to unsuspect
            // (though they're likely to if both are Mush as they're working together to clean each other's names)

            if (PPRL.bMush && KPRL.bMush) {
                NameClearIgnoreChance = NameClearChanceBothMush;
            }

            else {
                NameClearIgnoreChance = NameClearChanceNormal;
            }

            if (FRand() > NameClearIgnoreChance) {
                continue;
            }

            KPRL.RemoveHate(P.PlayerReplicationInfo);
            KPRL.bIsSuspected = False;
            bNameCleared = true;
        }
    }

    if (bNameCleared) {
        //MushMatch(Level.Game).BroadcastMessage(Killer.PlayerReplicationInfo.PlayerName$" had their suspicions lifted after being witnessed killing a mush,"@Other.PlayerReplicationInfo.PlayerName$"!", true, 'CriticalEvent');
        MushMatch(Level.Game).BroadcastUnsuspected(Killer.PlayerReplicationInfo, Other.PlayerReplicationInfo);

        return;
    }

    // Try to check suspects

    if (MMI.CheckConfirmedMush(Killer.PlayerReplicationInfo)) {
        return;
    }

    SuspectOverlookChance = SuspectHuntOverlookKillChance;

    if (MMI.CheckBeacon(Other.PlayerReplicationInfo)) {
        // Killing someone who is suspected is less bad!..?
        SuspectOverlookChance += (1.0 - SuspectOverlookChance) * OverlookChanceFactorTargetIsSuspect;
    }

    if (FRand() < SuspectOverlookChance && MMI.CheckBeacon(Other.PlayerReplicationInfo)) {
        return;
    }

    if (!MushMatch(Level.Game).bMushSelected) {
        return;
    }

    if (OPRL.bMush) {
        return;
    }

    CheckSuspects(Killer, Other);
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
    local float FlatSize, FlatScale, ImmuneShow;
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

    PlayerPRL = FindPawnPRL(PlayerOwner);

    if ( MushMatchInfo(PlayerOwner.GameReplicationInfo).bMushSelected && !PlayerPRL.bDead )
    {
        FlatScale = Drawer.SizeX * 0.05 / 128;
        FlatSize = 64;

        Drawer.DrawColor = BaseHUD.HUDColor * 0.75;
        Drawer.SetPos(Drawer.SizeX * 0.475, 0);

        if (!PlayerPRL.bMush) {
            Drawer.SetPos(Drawer.SizeX * 0.475, 0);

            if (PlayerPRL.ImmuneLevel < 1) {
                if (PlayerPRL.ImmuneLevel >= 0.) {
                    ImmuneShow = (FlatSize - 8) * (1.0 - PlayerPRL.ImmuneLevel);
                }

                else {
                    ImmuneShow = FlatSize - 8;
                }

                // Log("ImmuneShow is "$ImmuneShow$" and FlatSize is "$FlatSize);
                Drawer.SetPos(Drawer.CurX + 4, Drawer.CurY + 4);
                Drawer.DrawTile(Texture'MMHUDHumanNoimmune', FlatSize - 4, ImmuneShow, 0, 0, FlatSize * 2, ImmuneShow * 2);
                Drawer.SetPos(Drawer.CurX - 4, Drawer.CurY - 4);

                if (ImmuneShow < FlatSize) {
                    Drawer.SetPos(Drawer.SizeX * 0.475, ImmuneShow);
                    Drawer.DrawTile(Texture'MMHUDHuman', FlatSize, FlatSize - ImmuneShow, 0, -ImmuneShow * 2, FlatSize * 2, (FlatSize - ImmuneShow) * 2);
                }
            }

            else {
                Drawer.DrawIcon(Texture'MMHUDHuman', FlatScale);
            }
        }

        else {
            Drawer.DrawIcon(Texture'MMHUDMush', FlatScale);
        }

        Drawer.SetPos(Drawer.SizeX * 0.475, Drawer.SizeX * 0.05);

        if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bKnownMush )
            Drawer.DrawIcon(Texture'MMHUDKnownMush', FlatScale);

        else if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bKnownHuman )
            Drawer.DrawIcon(Texture'MMHUDKnownHuman', FlatScale);

        else if ( MushMatchPRL(MushMatchInfo(PlayerOwner.GameReplicationInfo).PRL.FindPlayer(PlayerOwner.PlayerReplicationInfo)).bIsSuspected )
            Drawer.DrawIcon(Texture'MMHUDSuspected', FlatScale);

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

    if (Level.NetMode == NM_DedicatedServer) {
        // Serverside HUD? whut?
        return false;
    }

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

    myPRL = FindPawnPRL(PlayerOwner);

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

            if (myPRL.bMush && !otherPRL.bMush) {
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
    NameClearChanceNormal=0.6
    NameClearChanceBothMush=0.9
    MinGuaranteeSuspectDamage=40
    VictimSuspectChance=0.9
    ScreamSuspectChance=0.6
    SuspectHuntOverlookKillChance=0.3
    SuspectHuntOverlookDamageChance=0.6
    OverlookChanceFactorTargetIsSuspect=0.6
}
