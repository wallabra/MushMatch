class MushMatchInfo extends TournamentGameReplicationInfo config(MushMatch);


replication
{
    reliable if (Role == ROLE_Authority)
        bMushSelected, bMatchEnd, bMatchStart, PRL,
        bScoreboardDrawScoreOnMatchEnd;
}


var     bool            bMushSelected, bMatchEnd, bMatchStart;
var     MushMatchPRL    PRL;
var     Music           MushDiscoveredMusic;
var     PlayerPawn      LocalPlayer;

// Replicated settings
var float
    DecideChance_Infect,
    DecideChance_SuspectAttack,
    DecideChance_GrudgeAttack,
    DecideChance_TeamUp,
    DecideChance_MushHelpMush,
    DecideChance_Scapegoat;

var bool bScoreboardDrawScoreOnMatchEnd;


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

    DecideChance_Infect             = MM.DecideChance_Infect;
    DecideChance_SuspectAttack      = MM.DecideChance_SuspectAttack;
    DecideChance_GrudgeAttack       = MM.DecideChance_GrudgeAttack;
    DecideChance_TeamUp             = MM.DecideChance_TeamUp;
    DecideChance_MushHelpMush       = MM.DecideChance_MushHelpMush;
    DecideChance_Scapegoat          = MM.DecideChance_Scapegoat;
    bScoreboardDrawScoreOnMatchEnd  = MM.bScoreboardDrawScoreOnMatchEnd;
}


simulated function PlayerPawn GetLocalPlayer() {
    if (Role == ROLE_Authority) {
        return None;
    }

    if (LocalPlayer != None) {
        return LocalPlayer;
    }

    foreach AllActors(class'PlayerPawn', LocalPlayer) {
        return LocalPlayer;
    }

    Warn(self @"found no local player found, but Role is not ROLE_Authority! Net mode:"@ Level.NetMode);
    return None;
}


simulated function PreSelected() {
    if (Role == ROLE_Authority && MushMatch(Level.Game) != None && MushMatch(Level.Game).DiscoveredMusic != "") {
        MushDiscoveredMusic = Music(DynamicLoadObject(MushMatch(Level.Game).DiscoveredMusic, class'Music'));

        if (MushDiscoveredMusic == None) {
            Warn("Could not find or load mush discovered music! ("$ MushMatch(Level.Game).DiscoveredMusic $")");
        }
    }
}


function bool RemovePRL(PlayerReplicationinfo PRI) {
    local bool success;
    local PlayerReplicationList newRoot;

    if (PRL != None) {
        newRoot = PRL;
        success = PRL.RemovePlayer(PRI, newRoot);
        PRL = MushMatchPRL(newRoot);
    }

    if (!success) {
        Warn("Could not find PRL to be removed for"@PRI.PlayerName);
    }

    return success;
}

function MushMatchPRL RegisterPRL(PlayerReplicationinfo PRI) {
    local MushMatchPRL NewPRL;

    if (PRL == None) {
        PRL = Spawn(class'MushMatchPRL', PRI);
        PRL.Root = PRL;
        NewPRL = PRL;
    }

    else if (PRL.FindPlayer(PRI) == None) {
        NewPRL = MushMatchPRL(PRL.AppendPlayer(PRI, class'MushMatchPRL'));
    }

    else {
        return None;
    }

    Log("Game replication registered PRL for"@ PRI.PlayerName);

    return NewPRL;
}

simulated function MushMatchPRL FindPRL(PlayerReplicationinfo PRI) {
    if (PRL == None)
        return None;

    return MushMatchPRL(PRL.FindPlayer(PRI));
}

simulated event bool CheckHate(PlayerReplicationInfo Hated, PlayerReplicationInfo Hater) {
    local MushMatchPRL PRLHated;

    if (Hater == None || Hated == None || PRL == None)
        return False;

    PRLHated = MushMatchPRL(PRL.FindPlayer(Hated));

    if (PRLHated == None)
        return False;

    return PRLHated.HasHate(Hater);
}

simulated function bool CheckAnyHate(PlayerReplicationInfo Hated) {
    local MushMatchPRL PRLHated;

    if (Hated == None || PRL == None)
        return False;

    PRLHated = MushMatchPRL(PRL.FindPlayer(Hated));

    if (PRLHated == None)
        return False;

    return PRLHated.HasAnyHate();
}

simulated function bool CheckBeacon(PlayerReplicationInfo Other)
{
    local MushMatchPRL list;

    if ( Other == None || PRL == None )
        return False;

    list = MushMatchPRL(PRL.FindPlayer(Other));

    if ( list != None )
    {
        // Log("bIsSuspected"@Other.PlayerName@list.bIsSuspected);
        return list.bIsSuspected;
    }

    return False;
}

simulated function Pawn CheckBeaconInstigator(PlayerReplicationInfo Other)
{
    local MushMatchPRL list;

    if ( Other == None || PRL == None )
        return None;

    list = MushMatchPRL(PRL.FindPlayer(Other));

    if ( list != None )
    {
        // Log("bIsSuspected"@Other.PlayerName@list.bIsSuspected);
        return list.Instigator;
    }

    return None;
}

simulated function bool CheckConfirmedMush(PlayerReplicationInfo Other)
{
    local MushMatchPRL list;

    if ( Other == None || PRL == None )
        return False;

    list = MushMatchPRL(PRL.FindPlayer(Other));

    if ( list != None )
    {
        // Log("bKnownMush"@Other.PlayerName@list.bKnownMush);
        return list.bKnownMush;
    }

    return False;
}

simulated function bool CheckConfirmedHuman(PlayerReplicationInfo Other)
{
    local MushMatchPRL list;

    if ( Other == None || PRL == None )
        return False;

    list = MushMatchPRL(PRL.FindPlayer(Other));

    if ( list != None )
    {
        // Log("bKnownHuman"@Other.PlayerName@list.bKnownHuman);
        return list.bKnownHuman;
    }

    return False;
}

simulated function bool CheckDead(PlayerReplicationInfo Other)
{
    local MushMatchPRL list;

    if (Other == None || PRL == None)
        return False;

    if (!bMushSelected)
        return False;

    list = FindPRL(Other);

    if ( list == None ) {
        return false;
    }

    // Log("bDead"@Other.PlayerName@list.bDead);
    return list.bDead;
}

simulated event string TeamText(PlayerReplicationInfo PRI, PlayerPawn Other)
{
    local MushMatchPRL OtherPRL, TargPRL;

    TargPRL = FindPRL(PRI);
    OtherPRL = FindPRL(Other.PlayerReplicationInfo);

    if (TargPRL == None) {
        return "???";
    }

    if (CheckDead(PRI)) {
        if (OtherPRL.bMush) {
            return "Mush (dead)";
        }

        else {
            return "Human (dead)";
        }
    }

    if (bMushSelected) {
        if (Other.PlayerReplicationInfo == PRI || (OtherPRL != None && OtherPRL.bMush) || bMatchEnd || CheckDead(Other.PlayerReplicationInfo)) {
            if (TargPRL.bMush) {
                if (CheckBeacon(PRI)) {
                    return "Mush (susp.)";
                }

                if (!CheckConfirmedMush(PRI)) {
                    return "Mush (unk.)";
                }
            }

            else {
                if (CheckConfirmedHuman(PRI)) {
                    return "Human (cert)";
                }

                else if ( CheckBeacon(PRI)) {
                    return "Human (susp.)";
                }

                else {
                    return "Human";
                }
            }
        }

        if (CheckBeacon(PRI))
            return "Suspected";

        if (!TargPRL.bMush && TargPRL.bKnownHuman) {
            return "Human (cert)";
        }

        if (TargPRL.bMush  && TargPRL.bKnownMush) {
            return "Mush (found)";
        }

        if (CheckBeacon(PRI) && !CheckConfirmedMush(PRI)) {
            return "Suspected";
        }

        return " - ";
    }

    return "...";
}

simulated event string TeamTextAlignment(PlayerReplicationInfo PRI, PlayerPawn Other)
{
    local MushMatchPRL MPRL;
    local MushMatchPRL OtherPRL;

    OtherPRL = FindPRL(Other.PlayerReplicationInfo);
    MPRL = FindPRL(PRI);

    if (MPRL == None) {
        return "???";
    }

    if (CheckDead(PRI)) {
        if (MPRL.bMush) {
            if (Int(MPRL.bMush) == MPRL.InitialTeam) {
                return "Mush";
            }

            else {
                return "* Mush";
            }
        }

        else {
            return "Human";
        }
    }

    if (bMushSelected) {
        if (Other.PlayerReplicationInfo == PRI || (OtherPRL != None && OtherPRL.bMush) || bMatchEnd || CheckDead(Other.PlayerReplicationInfo)) {
            if (MPRL.bMush) {
                MPRL = FindPRL(PRI);

                if (MPRL != None && Int(MPRL.bMush) == MPRL.InitialTeam) {
                    return "Mush";
                }

                else {
                    return "* Mush";
                }
            }

            else {
                return "Human";
            }
        }

        if (!MPRL.bMush && CheckConfirmedHuman(PRI)) {
            return "Human";
        }

        if (MPRL.bMush && CheckConfirmedMush(PRI)) {
            return "Mush";
        }

        return " - ";
    }

    return "...";
}

simulated event string TeamTextStatus(PlayerReplicationInfo PRI, PlayerPawn Other)
{
    local MushMatchPRL MPRL;

    MPRL = FindPRL(PRI);

    if (MPRL == None) {
        return "???";
    }

    if (CheckDead(PRI)) {
        return "[Dead]";
    }

    if (bMushSelected) {
        if (!MPRl.bMush && CheckConfirmedHuman(PRI)) {
            return "Certified";
        }

        if ( MPRl.bMush && CheckConfirmedMush(PRI)) {
            return "Discovered";
        }

        if (CheckBeacon(PRI)) {
            return "Suspected";
        }

        return " - ";
    }

    return "...";
}

function byte MushMatchAssessBotAttitude(Pawn aBot, Pawn Other) {
    local Pawn P;
    local MushMatchInfo MMI;
    local bool bNoSneaking;
    local PlayerReplicationInfo BotPRI, OtherPRI;
    local MushMatchPRL BotMPRL, OtherMPRL, PPRL;
    local Sporifier sporer;
    local MushMatch MM;

    MM = MushMatch(Level.Game);

    if (MM == None) {
        return 255;
    }

    if (!bMatchStart) {
        if (Other != None && !Other.bIsPlayer) {
            // Porbably a monster. Do whatever the default would be.
            return 255;
        }

        else {
            // Do nothing, just mind your own business.
            return 2;
        }
    }

    if (Other == None || aBot == None || Other.IsInState('Dying') || aBot.IsInState('Dying')) {
        //Warn("MushMatch cannot assess bot attitude for"@aBot@"toward"@Other$": either of them is None or dying");
        return 255;
    }

    if (!Other.bIsPlayer || !aBot.bIsPlayer) {
        // Default AssessBotAttitude - probably involves a monster or smsth
        return 255;
    }

    if (aBot.PlayerReplicationInfo == None || Other.PlayerReplicationInfo == None) {
        //Warn("MushMatch cannot assess bot attitude for"@aBot@"toward"@Other$": either of them has no PlayerReplicationInfo");
        return 2;
    }

    BotPRI = aBot.PlayerReplicationInfo;
    OtherPRI = Other.PlayerReplicationInfo;

    if (Role == ROLE_Authority) {
        MMI = MushMatchInfo(Level.Game.GameReplicationInfo);
    }

    else {
        MMI = MushMatchInfo(GetLocalPlayer().GameReplicationInfo);
    }

    if (MMI == None || (MMI.CheckDead(BotPRI) || MMI.CheckDead(OtherPRI))) {
        return 2;
    }

    if (aBot.bIsPlayer && Other.bIsPlayer && MM.NumBots + MM.NumPlayers - MM.TotalKills <= 2) {
        return 1; // just two players left, duke it out!!
    }

    BotMPRL = MMI.FindPRL(BotPRI);
    OtherMPRL = MMI.FindPRL(OtherPRI);

    if (BotMPRL == None || OtherMPRL == None) {
        //Warn("MushMatch cannot assess bot attitude for"@aBot@"toward"@Other$": either of them has no MushMatchPRL!");
        return 255;
    }

    // check for Mush-specific behaviour
    if (BotMPRL.bMush)
    {
        if (!OtherMPRL.bMush)
        {
            // if spotted or suspected mush, don't hold back
            if (BotMPRL.bKnownMush || BotMPRL.bIsSuspected) {
                return 1;
            }

            // maybe try to infect, if you can be sneaky!
            if (!Other.CanSee(aBot) && aBot.FindInventoryType(class'Sporifier') != None && FRand() < DecideChance_Infect && !aBot.IsInState('attacking')) {
                for (P = Level.PawnList; P != None; P = P.NextPawn) {
                    if (!P.bIsPlayer) continue;
                    if (P.PlayerReplicationInfo == None) continue;

                    PPRL = MMI.FindPRL(P.PlayerReplicationInfo);

                    if (PPRL == None) {
                        Warn("Found a bIsPlayer Pawn with PlayerReplicationInfo but no MushMatchPRL:"@ P);
                        continue;
                    }

                    if (PPRL.bMush) continue;

                    if (P.LineOfSightTo(aBot) && P != Other) {
                        bNoSneaking = true;
                    }
                }

                if (!bNoSneaking && (Other.MoveTarget == None || (
                    VSize(Other.Location - Other.MoveTarget.Location) > 128 &&
                    Normal(Other.MoveTarget.Location - Other.Location) dot Normal(aBot.Location - Other.Location) < -0.25
                ))) {
                    sporer = Sporifier(aBot.FindInventoryType(class'Sporifier'));

                    if (aBot.Weapon != sporer) {
                        sporer.SafeTime = 0;
                        sporer.bDesired = true;
                        sporer.BringUp();
                    }

                    return 1;
                }
            }

            return 2;
        }

        // mush help mush always
        else if (FRand() < DecideChance_MushHelpMush) {
            return 3;
        }
    }

    // check for general behaviour (or maybe a façade thereof) towards humans
    if (!BotMPRL.bMush || !OtherMPRL.bMush)
    {
        if (
            Other.bIsPlayer
            // if the other is not safe
            && !OtherMPRL.bKnownHuman
            &&
            (
                // if the other is DEFINITELY not safe, aka a mush
                OtherMPRL.bKnownMush
                ||
                (   // OR if we have a grudge on the other
                    MM.bHasHate
                    && !BotMPRL.bMush
                    && MMI.CheckHate(OtherPRI, BotPRI)
                    && !(OtherMPRL.bMush && BotMPRL.bMush)
                    && FRand() < DecideChance_GrudgeAttack
                )
                ||
                (
                    // OR if the other has a suspicion beacon
                    MM.bHasBeacon
                    && (
                        // if we're a human or scapegoating
                        !BotMPRL.bMush
                        || (
                            BotMPRL.bIsSuspected
                            && FRand() < DecideChance_Scapegoat
                        )
                    )
                    && MMI.CheckBeacon(Other.PlayerReplicationInfo)
                    && !MMI.CheckConfirmedMush(MMI.CheckBeaconInstigator(OtherPRI).PlayerReplicationInfo)
                    && FRand() < DecideChance_SuspectAttack
                )
            )
        ) {
            return 1;
        }

        // maybe be a friend and gang up, just in case - numbers always make might and make safety!
        // (always!.... right?)
        if (FRand() < DecideChance_TeamUp) {
            return 3;
        }
    }

    // ehh... we live in a society
    return 2;
}


defaultproperties {
    RemoteRole=ROLE_SimulatedProxy
    bMatchStart=false
    bMatchEnd=false
    bMushSelected=false
}
