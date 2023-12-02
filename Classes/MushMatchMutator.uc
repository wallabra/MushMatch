class MushMatchMutator extends DMMutator config(MushMatch);


var PlayerPawn PlayerOwner;


replication {
    reliable if (Role == ROLE_Authority)
        ScreamRadius, DirectionBlameRadius,

        VictimSuspectChance, ScreamSuspectChance,
        NameClearChanceNormal, NameClearChanceBothMush,
        SuspectHuntOverlookKillChance, SuspectHuntOverlookDamageChance,
        OverlookChanceFactorTargetIsSuspect, OverlookChanceFactorTargetIsSelf,
        OverlookChanceFactorWitnessSlyMush,

        SuspectDmgOverlookMaxDamage;
}


var bool bBeginplayed;

// Replicated settings
var float
    ScreamRadius,
    DirectionBlameRadius,
    SuspectDmgOverlookMaxDamage,
    VictimSuspectChance,
    ScreamSuspectChance,
    NameClearChanceNormal,
    NameClearChanceBothMush,
    SuspectHuntOverlookKillChance,
    SuspectHuntOverlookDamageChance,
    OverlookChanceFactorTargetIsSuspect,
    OverlookChanceFactorTargetIsSelf,
    OverlookChanceFactorWitnessSlyMush;


simulated function BeginPlay() {
    Super.BeginPlay();

    if (Role == ROLE_Authority) {
        UpdateConfigVars();
    }
}

// Update configuration from the MushMatch(Level.Game).
function UpdateConfigVars() {
    local MushMatch MM;
    MM = MushMatch(Level.Game);

    if (MM == None) {
        // rip
        Warn(class.name@"detected outside a Mush Match; gameinfo is"@Level.Game);
        return;
    }

    ScreamRadius                        = MM.ScreamRadius;
    DirectionBlameRadius                = MM.DirectionBlameRadius;
    SuspectDmgOverlookMaxDamage           = MM.SuspectDmgOverlookMaxDamage;
    VictimSuspectChance                 = MM.VictimSuspectChance;
    ScreamSuspectChance                 = MM.ScreamSuspectChance;
    NameClearChanceNormal               = MM.NameClearChanceNormal;
    NameClearChanceBothMush             = MM.NameClearChanceBothMush;
    SuspectHuntOverlookKillChance       = MM.SuspectHuntOverlookKillChance;
    SuspectHuntOverlookDamageChance     = MM.SuspectHuntOverlookDamageChance;
    OverlookChanceFactorTargetIsSuspect = MM.OverlookChanceFactorTargetIsSuspect;
    OverlookChanceFactorTargetIsSelf    = MM.OverlookChanceFactorTargetIsSelf;
    OverlookChanceFactorWitnessSlyMush  = MM.OverlookChanceFactorWitnessSlyMush;
}

function bool AlwaysKeep(Actor Other) {
    if ( Sporifier(Other) != None || SporeCanister(Other) != None || MushBeacon(Other) != None || MushBeaconAmmo(Other) != None )
        return true;

    return Super.AlwaysKeep(Other);
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

simulated event MutatorTakeDamage(out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
    local MushMatchInfo MMI;

    // Let other mutators process the damage before we decide upon it ourselves
    if ( NextDamageMutator != None ) {
        NextDamageMutator.MutatorTakeDamage(ActualDamage, Victim, InstigatedBy, HitLocation, Momentum, DamageType);
    }

    if (Role != ROLE_Authority) {
        return;
    }

    MMI = MushMatchInfo(Level.Game.GameReplicationInfo);

    // Ensure the match is already selected. Otherwise, zero the damage.
    if (!MMI.bMushSelected) {
        ActualDamage = 0;
        return;
    }

    if ( InstigatedBy == None || Victim == None || InstigatedBy == Victim || MMI == None ) {
        return;
    }

    if (MushMatch(Level.Game).bMushSelected) {
        // If already has suspicion beacon, skip; it would be redundant to check for suspicion!
        if ( MMI.CheckBeacon(Victim.PlayerReplicationInfo) ) {
            return;
        }

        // See if anyone saw that!
        CheckSuspects(InstigatedBy, Victim, ActualDamage);
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

    if (CHSpectator(Other) != None) {
        return;
    }

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

simulated function LinearChanceSkew(out float Chance, float Skew) {
    if (Skew == 0) {
        return;
    }

    if (Skew > 1) {
        Skew = 1;
    }

    if (Skew < -1) {
        Skew = -1;
    }

    if (Skew < 0) {
        Chance *= 1.0 + Skew;
    }

    else {
        Chance += (1.0 - Chance) * Skew;
    }
}

function bool BasicWitnessSuspect(Pawn Victim, Pawn InstigatedBy, Pawn Witness) {
    // Basic sanity checks for whether a bot's personal suspicion is valid.
    local MushMatchPRL WitPRL, VictPRL, InstigPRL;

    if (!Witness.bIsPlayer) {
        return false;
    }

    if (Witness.PlayerReplicationInfo == None) {
        Warn("Tried WitnessSuspect with a player witness without PRI:" @ Witness);
        return false;
    }

    if (InstigatedBy.PlayerReplicationInfo == None) {
        if (InstigatedBy.bIsPlayer) {
            Warn("Tried WitnessSuspect with a player instigator without PRI:" @ InstigatedBy);
        }

        return false;
    }

    if (Victim.PlayerReplicationInfo == None) {
        if (Victim.bIsPlayer) {
            Warn("Tried WitnessSuspect with a player victim without PRI:" @ Victim);
        }

        return false;
    }

    if (Witness.Health <= 0 || Witness.IsInState('Dying')) {
        return false;
    }

    if (Witness == InstigatedBy || Victim == InstigatedBy) {
        Warn("Tried WitnessSuspect where the instigator is also the victim/witness! Instigator:" @ InstigatedBy.PlayerReplicationInfo.PlayerName $"; victim:"@ Victim.PlayerReplicationInfo.PlayerName $"; witness:"@ Witness.PlayerReplicationInfo.PlayerName);
        return false;
    }

    // (only bots count!)
    if (PlayerPawn(Witness) != None) {
        return false;
    }

    WitPRL = FindPawnPRL(Witness);
    InstigPRL = FindPawnPRL(InstigatedBy);
    VictPRL = FindPawnPRL(Victim);

    // more sanity checks

    if (WitPRL == None || InstigPRL == None || VictPRL == None) {
        Warn("Missing PRLs among the witness, instigator and victim! Instigator:" @ InstigatedBy.PlayerReplicationInfo.PlayerName $"; victim:"@ Victim.PlayerReplicationInfo.PlayerName $"; witness:"@ Witness.PlayerReplicationInfo.PlayerName);
        return false;
    }

    if (Victim.Health <= 0 && VictPRL.bMush && !WitPRL.bMush) {
        return false;
    }

    if (WitPRL.bDead || InstigPRL.bDead || VictPRL.bDead) {
        return false;
    }

    // suspecting on someone who is a confirmed mush is a bit redundant innit
    if (InstigPRL.bKnownMush) {
        return false;
    }

    // make sure this suspicion does not already exist
    if (MushMatch(Level.Game).bHasHate && WitPRL.HasHateOnPRL(InstigPRL)) {
        return false;
    }

    // mush know who their comrades are, only pretend to suspect on humans, not fellow mush
    if (WitPRL.bMush && InstigPRL.bMush) {
        return false;
    }

    return true;
}

function bool WitnessSuspect(Pawn Victim, Pawn InstigatedBy, Pawn Witness, int Damage) {
    local MushMatchPRL WitPRL, VictPRL, InstigPRL;
    local float SuspectOverlookChance;

    if (!BasicWitnessSuspect(Victim, InstigatedBy, Witness)) {
        return false;
    }

    WitPRL = FindPawnPRL(Witness);
    InstigPRL = FindPawnPRL(InstigatedBy);
    VictPRL = FindPawnPRL(Victim);

    // must have line of sight to the perpetrator
    if (!Witness.LineOfSightTo(InstigatedBy)) {
        //Log("Ruled out suspicion for lack of line of sight to the perpetrator. Instigator:" @ InstigatedBy.PlayerReplicationInfo.PlayerName $"; victim:"@ Victim.PlayerReplicationInfo.PlayerName $"; witness:"@ Witness.PlayerReplicationInfo.PlayerName);
        return false;
    }

    // check that the instigator can be identified
    if (!(Witness.CanSee(InstigatedBy) || (Witness != Victim && Witness.CanSee(Victim)))) {
        // third-party witness check
        if (Witness != Victim) {
            // scream alerting
            if (VSize(InstigatedBy.Location - Witness.Location) + VSize(InstigatedBy.Location - Victim.Location) > ScreamRadius * 2 || FRand() > ScreamSuspectChance) {
                //Log("Ruled out suspicion for being too far for scream. Instigator:" @ InstigatedBy.PlayerReplicationInfo.PlayerName $"; victim:"@ Victim.PlayerReplicationInfo.PlayerName $"; witness:"@ Witness.PlayerReplicationInfo.PlayerName);
                return false;
            }
        }

        // victim's own check
        else {
            // know direction of your own hit, use to blame
            if (VSize(InstigatedBy.Location - Victim.Location) > DirectionBlameRadius || FRand() > VictimSuspectChance) {
                //Log("Ruled out suspicion for being too far for direction blame. Instigator:" @ InstigatedBy.PlayerReplicationInfo.PlayerName $"; victim:"@ Victim.PlayerReplicationInfo.PlayerName $"; witness:"@ Witness.PlayerReplicationInfo.PlayerName);
                return false;
            }
        }
    }

    //---------
    // at this point, all checks that could have ruled this out have passed.
    // now we're determining the chance of actually carrying out the suspicion.

    // weight the chance to overlook based on damage/kill
    if (Damage > 0 && Victim.Health > 0) {
        /*
        // cull small damage events, like falling over top of someone's head, but with a linear probability
        if (Damage < SuspectDmgOverlookMaxDamage && FRand() * SuspectDmgOverlookMaxDamage < Damage) {
            return false;
        }
        */

        SuspectOverlookChance = SuspectHuntOverlookDamageChance;

        if (Damage < SuspectDmgOverlookMaxDamage) {
            // Skew chance depending on how significant the damage was
            LinearChanceSkew(SuspectOverlookChance, Max(1.0 - Damage / SuspectDmgOverlookMaxDamage, 0.0));
        }
    }

    else {
        // was a kill
        SuspectOverlookChance = SuspectHuntOverlookKillChance;
    }

    // be less lax is the victim was oneself!
    if (Victim == Witness) {
        LinearChanceSkew(SuspectOverlookChance, OverlookChanceFactorTargetIsSelf);
    }

    else {
        // be more lax if the victim was suspected to begin with!
        if (VictPRL.bIsSuspected && !WitPRL.bMush) {
            LinearChanceSkew(SuspectOverlookChance, OverlookChanceFactorTargetIsSuspect);
        }
    }

    // be less lax if the witness is mush and the instigator is human
    if (WitPRL.bMush && !InstigPRL.bMush) {
        LinearChanceSkew(SuspectOverlookChance, OverlookChanceFactorWitnessSlyMush);
    }

    // debug
    //Log("Checking suspicion by"@ Witness.PlayerReplicationInfo.PlayerName @"on"@ InstigatedBy.PlayerReplicationInfo.PlayerName @"for bringing harming to"@ Victim.PlayerReplicationInfo.PlayerName $", chance is"@ (1.0 - SuspectOverlookChance) * 100 $ "%");

    // finally act upon the overlook chance! dice roll.. and drum roll...
    if (FRand() < SuspectOverlookChance) {
        return false;
    }

    // raise an eyebrow!
    return true;
}

function CheckSuspects(Pawn InstigatedBy, Pawn Victim, int Damage)
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
        // P can also be Victim, but not InstigatedBy.

        if (P != InstigatedBy && !WitnessSuspect(Victim, InstigatedBy, P, Damage)) {
            continue;
        }

        MushMatch(Level.Game).RegisterHate(P, InstigatedBy);
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
    local float NameClearIgnoreChance;

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

            // Ensure they are alive
            if (P.Health <= 0 || P.IsInState('Dying')) {
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

    if (!MushMatch(Level.Game).bMushSelected) {
        return;
    }

    if (OPRL.bMush) {
        return;
    }

    CheckSuspects(Killer, Other, -1);
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
    local int Linefeed, TargetHealth;

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

            if (myPRL.bMush && !otherPRL.bMush && !otherPRL.bDead) {
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

            if ((myPRL.bMush && otherPRL.bMush) || myPRL.bDead) {
                // Display health
                TargetHealth = Pawn(IdentifyTarget.Owner).Health;

                if (Pawn(IdentifyTarget.Owner).Health < 30) {
                    Drawer.DrawColor = BaseHUD.RedColor;
                }

                BaseHUD.DrawTwoColorID(Drawer,
                                       "Health",
                                       Health,
                                       Drawer.ClipY - (256 - Linefeed) * BaseHUD.Scale));
                Linefeed += 24;

                Drawer.DrawColor = BaseHUD.GreenColor;
            }
        }
    }

    return true;
}


defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
    bNetTemporary=True
}
