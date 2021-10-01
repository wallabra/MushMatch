#exec AUDIO IMPORT FILE="Sounds\mm_found.wav" NAME="FoundMush" GROUP="MushMatch"
#exec AUDIO IMPORT FILE="Sounds\mm_suspect.wav" NAME="Suspected" GROUP="MushMatch"

class MushMatch expands DeathMatchPlus;


replication
{
    reliable if ( Role == ROLE_Authority )
        bMushSelected, bHumanVictory, bMatchEnd, bHasHate, bHasBeacon, winTeam,
        RegisterHate, SpotMush, StrapBeacon;
}


var(MushMatch) config bool bHighDetailGhosts;
var(MushMatch) config string DiscoveredMusic;
var(MushMatch) config float MushScarceRatio;
var(MushMatch) config class<Spectator> SpectatorClass;
var(MushMatch) config class<LocalMessagePlus> MushDiedMessageType, MushSpottedMessageType, MushSuspectedMessageType, MushSelectedMessageType;
var(MushMatch) config bool bMushUseOwnPronoun;
var(MushMatch) config float DecideChance_Infect, DecideChance_SuspectAttack, DecideChance_GrudgeAttack, DecideChance_TeamUp, DecideChance_MushHelpMush, DecideChance_Scapegoat;
var(MushMatch) config float SpawnChance_BeaconAmmo, SpawnChance_SporeAmmo;
var(MushMatch) localized string RTeamNames[2];

var bool bMushSelected, bHumanVictory, bMatchEnd, bHasHate, bHasBeacon;
var byte winTeam;
var int TotalKills;
var PlayerReplicationInfo StrawmanInfo;



event bool RegisterHate(Pawn Hater, Pawn Hated)
{
    if (!bMushSelected)
        return false;

    if (Hater == None || Hated == None)
        return false;

    bHasHate = true;
    
    MushMatchPRL(MushMatchInfo(GameReplicationInfo).PRL.FindPlayer(Hated.PlayerReplicationInfo)).AddHate(Hater.PlayerReplicationInfo);
    
    return true;
}

function SpreadMatchAmmo() {
    local navigationPoint np;
    
    foreach AllActors(class'NavigationPoint', np)
    {
        if ( FRand() < SpawnChance_BeaconAmmo ) np.Spawn(class'MushBeaconAmmo');
        else if ( FRand() < SpawnChance_SporeAmmo ) np.Spawn(class'SporeCanister');
    }
}

event InitStrawmanInfo() {
    // Required to "censor" frag messages and keep killers anonymous.
    
    StrawmanInfo = Spawn(class'PlayerReplicationInfo', Self,, vect(0,0,0), rot(0,0,0));
    StrawmanInfo.Team = 254; // to prevent being rendered by the scoreboard

    ShuffleStrawmanName();
}

event InitGame(string Options, out string Error) {
    Super.InitGame(Options, Error);

    InitStrawmanInfo();
    SpreadMatchAmmo();
}

function PostBeginPlay()
{
    local Pawn P;

    Super.PostBeginPlay();
    
    SetTimer(0.5, true);
    
    for ( P = Level.PawnList; P != none; P = P.nextPawn )
        if ( P.bIsPlayer && p.PlayerReplicationInfo != none )
            p.PlayerReplicationInfo.Team = 0;

    bFirstBlood     = true;                    // we do not want first blood messages announcing killers
    LastTauntTime   = Level.TimeSeconds + 120; // auto-taunts also make it easy to spot killers, leave disabled for 2 mins.
}

function Logout(pawn Exiting)
{
    local MushMatchPRL MPRL;

    Super.Logout(Exiting);

    if (bMatchEnd) {
        return;
    }

    if (Exiting.bIsPlayer && Exiting.PlayerReplicationInfo != None) {
        MPRL = MushMatchInfo(GameReplicationInfo).FindPRL(Exiting.PlayerReplicationInfo);

        if (bMushSelected) {
            CheckEnd();
        }

        if (MPRL.bDead) {
            TotalKills--;
        }

        MushMatchInfo(GameReplicationInfo).RemovePRL(Exiting.PlayerReplicationInfo);
    }
}

function bool NeedPlayers()
{
    if ( bGameEnded || TotalKills > 0.15 * (NumPlayers + NumBots) )
        return false;

    return (NumPlayers + NumBots < MinPlayers);
}

event playerpawn Login
(
    string Portal,
    string Options,
    out string Error,
    class<playerpawn> SpawnClass
)
{
    local playerpawn NewPlayer; 

    // if more than 15% of the game is over, must join as spectator
    if ( bMushSelected && Level.NetMode != NM_Standalone && TotalKills > 0.15 * (NumPlayers + NumBots) ) {
        bDisallowOverride = true;
        SpawnClass = SpectatorClass;
        
        if ( (NumSpectators >= MaxSpectators) && ((Level.NetMode != NM_ListenServer) || (NumPlayers > 0)) ) {
            MaxSpectators++;
        }
    }
    
    NewPlayer = Super.Login(Portal, Options, Error, SpawnClass);

    if (NewPlayer != None) {
        SetUpPlayer(NewPlayer);
    }

    return NewPlayer;
}

function Killed(Pawn Killer, Pawn Other, name DamageType)
{
    local vector hLoc, hMom;
    local int dmg;

    local MushMatchPRL OPRL;
    
    hLoc = Other.Location;
    hMom = vect(0,0,0);
    dmg = 32767;

    if (Killer != None && Killer.bIsPlayer && (!Killer.PlayerReplicationInfo.bIsABot || Killer.PlayerReplicationInfo.Team == 1))
        LastTauntTime   = Level.TimeSeconds + 6; // auto-taunts also make it easy to spot killers, disable for 6 seconds for players and mushes

    OPRL = MushMatchInfo(GameReplicationInfo).FindPRL(Other.PlayerReplicationInfo);

    DiscardInventory(Other);

    if (Other.PlayerReplicationInfo == None || (Killer != None && Killer.PlayerReplicationInfo == None)) {
        Super.Killed(Killer, Other, DamageType);

        if (!bMushSelected) {
            Other.PlayerReplicationInfo.Deaths = 0;
            Other.PlayerReplicationInfo.Score = 0;
            
            if (Killer != None)
                Killer.PlayerReplicationInfo.Score = 0;
        }

        return;
    }
    
    if (bMushSelected && Other.bIsPlayer) {
        if (Other.PlayerReplicationInfo != None) {
            BroadcastDeceased(Other.PlayerReplicationInfo);
        }

        if (Killer != None && Killer.bIsPlayer) {
            if (OPRL != None) {
                OPRL.bDead = true;
                TotalKills += 1;
            }

            else {
                // Really bad stuff! Debugging is important!
            
                Warn("MushMatch replication list entry for"@ Other.PlayerReplicationInfo.PlayerName @"not found!");
                Log("Found:");

                for (OPRL = MushMatchInfo(GameReplicationInfo).PRL; OPRL != None; OPRL = MushMatchPRL(OPRL.next))
                    Log(" * "@ PlayerReplicationInfo(OPRL.Owner).PlayerName @"("$ OPRL @ OPRL.Owner $ ") - next:"@ OPRL.next);
            }
        }
    }
        
    if (!bMushSelected) {
        Super.Killed(Killer, Other, DamageType);
        
        Other.PlayerReplicationInfo.Deaths = 0;
        Other.PlayerReplicationInfo.Score = 0;
        
        if (Killer != None)
            Killer.PlayerReplicationInfo.Score = 0;
        
        return;
    }

    if (Killer == None) {
        Super.Killed(Killer, Other, DamageType);
    
        if ( bMushSelected )
        {
            MushMatchMutator(BaseMutator).MutatorScoreKill(None, Other);

            CheckEnd();
        }
        
        return;
    }
    
    if (!Killer.bIsPlayer || !Other.bIsPlayer) {
        Super.Killed(Killer, Other, DamageType);
        
        return;
    }

    MushMatchMutator(BaseMutator).MutatorScoreKill(Killer, Other);
    Super.Killed(Killer, Other, DamageType);
    
    if ( bMatchEnd )
        return;

    if ( PlayerPawn(Other) != none )
        PlayerPawn(Other).PlayerReplicationInfo.Deaths += 1;
        
    CheckEnd();
}
    
function CheckEnd()
{
    local int h, m;

    if ( !bMushSelected || bMatchEnd )
        return;
    
    GetAliveTeams(h, m);
        
    if ( h == 0 || m == 0 ) SetEndCams("teamstand");
}

function GetAliveTeams(out int humans, out int mush) {
    local Pawn p;
    local MushMatchPRL PRL;

    if (!bMushSelected) {
        humans = 1;
        mush = 1;
        
        return;
    }
        
    for (p = Level.PawnList; p != none; p = p.nextPawn) {
        if (p.bIsPlayer && p.PlayerReplicationInfo != none && !p.IsInState('Dying')) {
            // guarantee that the player is not dead and e.g. spectating

            PRL = MushMatchInfo(GameReplicationInfo).FindPRL(p.PlayerReplicationInfo);

            if (!PRL.bDead) {
                if (p.PlayerReplicationInfo.Team == 0) {
                    humans += 1;
                }
            
                if (p.PlayerReplicationInfo.Team == 1) {
                    mush += 1;
                }
            }
        }
    }
}

function bool SetEndCams(string Reason)
{
    local float EndTime;
    local Pawn P, RWinner;
    local PlayerPawn Player;
    local int h, m;

    GetAliveTeams(h, m);

    if (h != 0 && (TimeLimit == 0 || RemainingTime != 0 || h > m)) {
        winTeam = 0;
    }
        
    else {
        winTeam = 1;
    }

    BroadcastMessage("The"@RTeamNames[winTeam]@GameEndedMessage);

    bMatchEnd = true;
    MushMatchInfo(GameReplicationInfo).bMatchEnd = true;
    EndTime = Level.TimeSeconds + 3.0;
    GameReplicationInfo.GameEndedComments = "The"@RTeamNames[winTeam]@GameEndedMessage;
    log("Game ended at "$EndTime);
    
    for ( P=Level.PawnList; P!=None; P=P.nextPawn )
    {
        if ( P.bIsPlayer && P.PlayerReplicationInfo != none && P.PlayerReplicationInfo.Team == winTeam && P.PlayerReplicationInfo.Deaths <= 0 && ( RWinner == none || P.PlayerReplicationInfo.Score > RWinner.PlayerReplicationInfo.Score ) )
            RWinner = P;
    }
    
    for ( P=Level.PawnList; P!=None; P=P.nextPawn )
    {
        Player = PlayerPawn(P);
        
        if ( Player != None )
        {
            if (!bTutorialGame)
                PlayWinMessage(Player, (Player.PlayerReplicationInfo.Team == winTeam));
                
            Player.bBehindView = true;
            
            if ( RWinner != None )
                Player.ViewTarget = RWinner;
                
            else
                Player.ViewTarget = Player;
                
            Player.ClientGameEnded();
        }

        P.GotoState('GameEnded');
    }
    
    CalcEndStats();
    GotoState('GameEnded');
    
    return true;
}

function bool StrapBeacon(Pawn Other, optional Pawn Suspector)
{
    local MushMatchPRL OtherPRL, SuspectorPRL;
    
    if (!bMushSelected)
        return False;

    if (Other == None)
        return False;

    if (Suspector != None && Suspector.PlayerReplicationInfo != None && Suspector.PlayerReplicationInfo.Team == 1) {
        SuspectorPRL = MushMatchInfo(GameReplicationInfo).FindPRL(Suspector.PlayerReplicationInfo);

        if (SuspectorPRL != None && SuspectorPRL.bKnownMush)
            return False; // known mush can't suspect
    }

    if (MushMatchInfo(GameReplicationInfo).CheckConfirmedHuman(Other.PlayerReplicationInfo)) {
        return False; // confirmed humans can't be suspected, only spotted!
    }
        
    bHasBeacon = true;
    
    if (MushMatchInfo(GameReplicationInfo).CheckBeacon(Other.PlayerReplicationInfo))
        return False;  // Already has beacon, but for that same reason the act of strapping did not succeed, so False.

    OtherPRL = MushMatchInfo(GameReplicationInfo).FindPRL(Other.PlayerReplicationInfo);
    
    if (OtherPRL != None) {
        if (PlayerPawn(Other) != None)
            PlayerPawn(Other).PlayOwnedSound(sound'Suspected');
            
        //BroadcastMessage(Suspector.PlayerReplicationInfo.PlayerName@"attached a suspicion beacon on"@Other.PlayerReplicationInfo.PlayerName$"!", true, 'CriticalEvent');
        BroadcastSuspected(Suspector.PlayerReplicationInfo, Other.PlayerReplicationInfo);
        
        OtherPRL.bIsSuspected = True;
        OtherPRL.Instigator = Suspector;
    
        //Log("SUSPECTING ON: "@Other.PlayerReplicationInfo.PlayerName @ OtherPRL);
    }
    
    return OtherPRL != None;
}

function StartMatch()
{	
    local Pawn P;

    Super.StartMatch();

    for ( P = Level.PawnList; P != None; P = P.NextPawn )
        if ( P.bIsPlayer && P.PlayerReplicationInfo != None )
            P.PlayerReplicationInfo.Team = 0;

    MushMatchInfo(GameReplicationInfo).bMatchStart = true;
    GoToState('GameStarted');
}

function int ReduceDamage(int Damage, name DamageType, pawn injured, pawn instigatedBy)
{
    return Super(DeathMatchPlus).ReduceDamage(Damage, DamageType, injured, instigatedBy);
}

function byte AssessBotAttitude(Bot aBot, Pawn Other)
{
    local Pawn P;
    local MushMatchInfo MMI;
    local bool bNoSneaking;
    local PlayerReplicationInfo BotPRI, OtherPRI;
    local MushMatchPRL BotMPRL, OtherMPRL;
    local Sporifier sporer;
    
    if (Other == None || aBot == None || !Other.bIsPlayer || !aBot.bIsPlayer || Other.IsInState('Dying') || aBot.IsInState('Dying')) {
        //Log("MushMatch cannot assess bot attitude for"@aBot@"toward"@Other$": either of them is None or dying or not player");
        return Super.AssessBotAttitude(aBot, Other);
    }
    
    if (aBot.PlayerReplicationInfo == None || Other.PlayerReplicationInfo == None) {
        //Log("MushMatch cannot assess bot attitude for"@aBot@"toward"@Other$": either of them has no PlayerReplicationInfo");
        return 2;
    }

    MMI = MushMatchInfo(GameReplicationInfo);

    if (MMI == None || (MMI.CheckDead(aBot.PlayerReplicationInfo) || MMI.CheckDead(Other.PlayerReplicationInfo))) {
        return 2;
    }

    if (aBot.bIsPlayer && Other.bIsPlayer && NumBots + NumPlayers - TotalKills <= 2) {
        return 1; // just two players left, duke it out!!
    }

    BotPRI = aBot.PlayerReplicationinfo;
    OtherPRI = Other.PlayerReplicationInfo;
    BotMPRL = MMI.FindPRL(BotPRI);
    OtherMPRL = MMI.FindPRL(OtherPRI);

    // check for Mush-specific behaviour
    if (BotPRI.Team == 1)
    {
        if (OtherPRI.Team == 0)
        {
            // if spotted mush, don't hold back
            if (BotMPRL.bKnownMush) {
                return 1;
            }

            // maybe try to infect, if you can be sneaky!
            if (!Other.CanSee(aBot) && aBot.FindInventoryType(class'Sporifier') != None && FRand() < DecideChance_Infect) {
                for (P = Level.PawnList; P != None; P = P.NextPawn) {
                    if (P.bIsPlayer && P.PlayerReplicationInfo != None && P.PlayerReplicationInfo.Team == 0 && P.LineOfSightTo(aBot) && P != Other) {
                        bNoSneaking = true;
                    }
                }

                if (!bNoSneaking && (Other.MoveTarget == None || (
                    VSize(Other.Location - Other.MoveTarget.Location) > 128 &&
                    Normal(Other.MoveTarget.Location - Other.Location) dot Normal(aBot.Location - Other.Location) < -0.25
                ))) {
                    sporer = Sporifier(aBot.FindInventoryType(class'Sporifier'));

                    if (aBot.Weapon != sporer) {
                        sporer.BringUp();
                        sporer.SafeTime = 0;
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
    if (BotPRI.Team == 0 || OtherPRI.Team == 0)
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
                    bHasHate
                    && BotPRI.Team == 0
                    && MMI.CheckHate(OtherPRI, BotPRI)
                    && !(OtherPRI.Team == 1 && BotPRI.Team == 1)
                    && FRand() < DecideChance_GrudgeAttack
                )
                ||
                (
                    // OR if the other has a suspicion beacon
                    bHasBeacon
                    && (
                        // if we're a human or scapegoating
                        BotPRI.Team == 0
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

    //return Super.AssessBotAttitude(aBot, Other);
}

// Unset the enemy of a pawn
function UnsetEnemy(Pawn Other) {
    // Don't meddle with players. They're snobby and weird.
    if (PlayerPawn(Other) != None) {
        return;
    }

    Other.Enemy = None;

    // Avoid bots in the Attacking state with Enemy set to None.
    if (Bot(Other) != None && Bot(Other).IsInState('Attacking')) {
        Bot(Other).WhatToDoNext('', '');
    }
}

function SafeGiveSporifier(Pawn Other) {
    local Weapon w;
    
    w = Other.Weapon;
                
    Spawn(class'Sporifier').GiveTo(Other);

    if (Other.Weapon != w) {
        Other.Weapon = w;

        if (Sporifier(Other.PendingWeapon) != None) {
            Other.PendingWeapon = None;
            w.BringUp(); // just in case
        }
    }
}

function MakeMush(Pawn Other, Pawn Instigator) {
    SafeGiveSporifier(Other);
    
    Other.PlayerReplicationInfo.Team = 1; // 0 = human, 1 = mush
    
    Instigator.PlayerReplicationInfo.Score += 1;
        
    mushmatch(Level.Game).CheckEnd();
    
    if ( Other.Enemy == Instigator ) UnsetEnemy(Other);
    if ( Other == Instigator.Enemy ) UnsetEnemy(Instigator);
    
    // -- Infections are low-key, don't alert everyone in a newly infected mush's vicinity, that's dumb. -- {
    //     for ( p = Level.PawnList; p != none; p = p.nextPawn )
    //         if ( p.bIsPlayer && p != Other && p.PlayerReplicationInfo != none && p.PlayerReplicationInfo.Deaths <= 0 && p.CanSee(Other) && Other.PlayerReplicationInfo.Team == 1  && p.PlayerReplicationInfo.Team == 0 )
    //             mushmatch(Level.Game).SpotMush(Other, p);
    // }
            
    if (PlayerPawn(Other) != None && !MushMatch(Level.Game).bMatchEnd) {
        Other.PlayOwnedSound(sound'Infected');
    }
}

function bool SpotMush(Pawn Other, Pawn Finder)
{
    local MushMatchPRL OtherPRL;
    local PlayerReplicationInfo FinderPRI, OtherPRI;
    local MushMatchInfo MMI;

    MMI = MushMatchInfo(GameReplicationInfo);

    if (Other == None || Finder == None || !Other.bIsPlayer || Other.PlayerReplicationInfo == none || MMI.CheckConfirmedMush(Other.PlayerReplicationInfo))
        return False;

    OtherPRL = MMI.FindPRL(Other.PlayerReplicationInfo);
    OtherPRI = Other.PlayerReplicationInfo;
    FinderPRI = Finder.PlayerReplicationInfo;
    
    if (OtherPRL != None) {
        /* -- old method
           BroadcastMessage(OtherPRI.Playername@"was discovered as mush!", true, 'CriticalEvent');
         * -- */

        BroadcastSpotted(FinderPRI, OtherPRI);
        
        if (PlayerPawn(Other) != None && DiscoveredMusic != "")
        {
            Log("Playing discovered music"@ DiscoveredMusic @"for:"@ OtherPRI.PlayerName);
            Spawn(class'MushMusic', Other);
        }
        
        if (PlayerPawn(Other) != None)
            Other.PlayOwnedSound(sound'FoundMush');

        OtherPRL.bKnownMush = True;
        
        OtherPRL.bIsSuspected = False;
        OtherPRL.bKnownHuman = False;
        OtherPRL.Instigator = None;     // also clear instigator field (which is used only for people with suspicion beacons)
        
        return True;
    }

    else
        Warn("SpotMush failed; no PRL could be found for"@ OtherPRI.PlayerName $"!");

    return False;
}

event ShuffleStrawmanName() {
    // Shuffles the StrawmanInfo's name everytime
    // a frag must be broadcast.

    local string    Res;
    local string    NoiseChars;
    local int       Size;
    local int       MaxIndex;
    
    NoiseChars      = "!@#$--..,,.:;''";
    MaxIndex        = Len(NoiseChars);
    
    for (Size = Rand(25) + 8; Size > 0; Size--) {
        Res = Res $ Mid(NoiseChars, Rand(MaxIndex), 1);
    }
    
    StrawmanInfo.PlayerName = Res;
}

event BroadcastRegularDeathMessage(pawn Killer, pawn Other, name damageType)
{
    ShuffleStrawmanName();

    if (damageType == 'RedeemerDeath')
    {
        if ( RedeemerClass == None )
            RedeemerClass = class<Weapon>(DynamicLoadObject("Botpack.Warheadlauncher", class'Class'));
            
        BroadcastLocalizedMessage(DeathMessageClass, 0, StrawmanInfo, Other.PlayerReplicationInfo, RedeemerClass);
    }
    
    else if (damageType == 'Eradicated')
        BroadcastLocalizedMessage(class'EradicatedDeathMessage', 0, StrawmanInfo, Other.PlayerReplicationInfo, None);
        
    else if ((damageType == 'RocketDeath') || (damageType == 'GrenadeDeath'))
        BroadcastLocalizedMessage(DeathMessageClass, 0, StrawmanInfo, Other.PlayerReplicationInfo, class'UT_Eightball');
        
    else if (damageType == 'Gibbed')
        BroadcastLocalizedMessage(DeathMessageClass, 8, StrawmanInfo, Other.PlayerReplicationInfo, None);
        
    else {
        if (Killer.Weapon != None)
            BroadcastLocalizedMessage(DeathMessageClass, 0, StrawmanInfo, Other.PlayerReplicationInfo, Killer.Weapon.Class);
            
        else
            BroadcastLocalizedMessage(DeathMessageClass, 0, StrawmanInfo, Other.PlayerReplicationInfo, None);
    }
}

function bool RestartPlayer(Pawn aPlayer)
{
    local MushMatchPRL APRL;

    if ( bMatchEnd ) {
        return false;
    }

    APRL = MushMatchInfo(GameReplicationInfo).FindPRL(aPlayer.PlayerReplicationInfo);

    if (APRL != None) {
        if (APRL.bDead && bMushSelected)
        {
            if (aPlayer.IsA('Bot')) {
                // bots don't respawn when ghosts
                aPlayer.PlayerReplicationInfo.bIsSpectator = true;
                aPlayer.PlayerReplicationInfo.bWaitingPlayer = true;
                aPlayer.GotoState('GameEnded');
                return false;
            }
        }
    }

    if (!Super.RestartPlayer(aPlayer)) {
        return false;
    }

    if (APRL != None) {
        if (bMushSelected)
        {
            if (APRL.bDead) {
                // This guy is a ghost. Add a visual effect.
                if ( bHighDetailGhosts )
                {
                    aPlayer.Style = STY_Translucent;
                    aPlayer.ScaleGlow = 0.5;
                } 

                else {
                    aPlayer.bHidden = true;
                }

                aPlayer.PlayerRestartState = 'PlayerSpectating';
            }
        }

        else {
            APRL.bDead = False;
        }
    }
    
    return true;
}

function bool SetUpPlayer(Pawn P)
{
    local MushMatchPRl prl;

    if (P == None) {
        Warn("SetUpPlayer failed; was called with None!");
        return false;
    }

    if (CHSpectator(P) == None) {
        if (bMushSelected && FRand() * MushScarceRatio < 1.0) {
            P.PlayerReplicationInfo.Team = 1;
        }
            
        else {
            P.PlayerReplicationInfo.Team = 0;
        }
    }

    prl = MushMatchInfo(GameReplicationInfo).FindPRL(P.PlayerReplicationInfo);
    
    if (prl == None) {
        prl = MushMatchInfo(GameReplicationInfo).RegisterPRL(P.PlayerReplicationInfo);

        if (prl == None) {
            Warn("Player lacked a PRL, but new one couldn't be created! ("$ P.PlayerReplicationInfo.PlayerName $")");
        }
    }

    // treat spectators like dead players
    if (CHSpectator(P) != None) {
        prl.bDead = True;
    }

    return prl != None;
}

function AddDefaultInventory(Pawn PlayerPawn)
{
    Super.AddDefaultInventory(PlayerPawn);
    
    if (Role == ROLE_Authority && PlayerPawn(PlayerPawn) == None /* AKA bots */) SetUpPlayer(PlayerPawn);
}

function bool ChangeTeam(Pawn Other, int N) 
{
    if (!bMushSelected) {
        Other.PlayerReplicationInfo.Team = 0;
        return true;
    }

    if (bGameEnded || TotalKills > 0.15 * (NumPlayers + NumBots) || CHSpectator(Other) != None) {
        // the spectator edge case is handled elsewhere
        return true;
    }

    if (FRand() * MushScarceRatio < 1.0) {
        Other.PlayerReplicationInfo.Team = 1;
    }

    else {
        Other.PlayerReplicationInfo.Team = 0;
    }

    MushMatchInfo(GameReplicationInfo).FindPRL(Other.PlayerReplicationInfo).SetInitialTeam();

    return true;
}

function int CountPlayers()
{
    local int i;
    local Pawn p;
    
    for ( p = Level.PawnList; p != none; p = p.NextPawn )
        if ( p.bIsPlayer )
            i++;
            
    return i;
}

function int MushCount()
{
    local int i;
    local Pawn p;
    
    for ( p = Level.PawnList; p != none; p = p.NextPawn )
        if ( p.bIsPlayer && p.PlayerReplicationInfo != none && p.PlayerReplicationInfo.Team == 1 )
            i++;

    return i;
}

function Selected()
{
    local Pawn p;
    local Sporifier sp;
    local MushMatchPRL PRL;

    foreach AllActors(class'Sporifier', sp) {
        sp.MushSelected();
    }

    for ( p = Level.PawnList; p != none; p = p.NextPawn ) {
        if ( p.bIsPlayer && p.PlayerReplicationInfo != none )
        {
            p.Health = Max(p.Health, p.Class.Default.Health);

            PRL = MushMatchInfo(GameReplicationInfo).FindPRL(p.PlayerReplicationInfo);
            PRL.SetInitialTeam();
        }
    }

    BroadcastLocalizedMessage(MushSelectedMessageType);
}

auto state Idle {}

state GameStarted
{
    function SelectTraitor()
    {
        local Pawn p, c;
        local bool b;  
        
        while ( p == none )
        {
            for ( c = Level.PawnList; c != none; c = c.nextPawn )
            {
                if ( c.bIsPlayer )
                    b = true;
            
                if ( FRand() * (NumPlayers + NumBots) < 1.0 && c.bIsPlayer && c.PlayerReplicationInfo != none && c.PlayerReplicationInfo.Team == 0 )
                    p = c;
            }
            
            if ( !b )
                Error("Match has no players!");
        }
                    
        p.PlayerReplicationInfo.Team = 1;
        SafeGiveSporifier(p);
        
        // Log(p@"("$p.PlayerReplicationInfo.PlayerName$") is now mush!");
    }
    
Begin:
    Sleep(10.0);
    MushMatchInfo(GameReplicationInfo).PreSelected();

    while ( CountPlayers() > MushCount() * MushScarceRatio || MushCount() == 0 )
        SelectTraitor();

    Sleep(0.25); // grace time for replication
    Selected();
    
    bMushSelected = true;
    MushMatchInfo(GameReplicationInfo).bMushSelected = true;
}

function BroadcastDeceased(PlayerReplicationInfo Who) {
    BroadcastLocalizedMessage(MushDiedMessageType, int(bMushUseOwnPronoun), Who);
}

function BroadcastSpotted(PlayerReplicationInfo By, PlayerReplicationInfo Whom) {
    BroadcastLocalizedMessage(MushSpottedMessageType, 0, Whom, By);
}

function BroadcastSuspected(PlayerReplicationInfo By, PlayerReplicationInfo Whom) {
    BroadcastLocalizedMessage(MushSuspectedMessageType, 0, Whom, By);
}

function BroadcastUnsuspected(PlayerReplicationInfo Whom, PlayerReplicationInfo Victim) {
    BroadcastLocalizedMessage(MushSuspectedMessageType, 1, Whom, Victim);
}

state GameEnded
{
Begin:
    Sleep(8);

    if ( Level.NetMode != NM_Standalone )
        EndGame("net end game");
}

defaultproperties
{
     DiscoveredMusic="Cannon.Cannon"
     RTeamNames(0)="Humans"
     RTeamNames(1)="Mushes"
     bUseTranslocator=True
     StartUpMessage="Kill any suspiciously mush players to win the match! Don't trust team colors."
     GameEndedMessage="win the match!"
     MaxCommanders=0
     bCoopWeaponMode=True
     ScoreBoardType=Class'MushMatchScoreBoard'
     //HUDType=Class'MushMatchHUD'
     BeaconName="MUSH"
     GameName="Mush Match {{{version}}}{{{namesuffix}}}"
     GameReplicationInfoClass=Class'MushMatchInfo'
     MutatorClass=Class'MushMatchMutator'
     bAlwaysForceRespawn=True
     MushScarceRatio=5.0
     SpectatorClass=class'CHSpectator'
     MushDiedMessageType=Class'MushDiedMessage'
     MushSpottedMessageType=Class'MushSpottedMessage'
     MushSuspectedMessageType=Class'MushSuspectedMessage'
     MushSelectedMessageType=Class'MushSelectedMessage'
     bMushUseOwnPronoun=True
     DecideChance_Infect=0.75
     DecideChance_SuspectAttack=0.5
     DecideChance_GrudgeAttack=0.8
     DecideChance_TeamUp=0.35
     DecideChance_MushHelpMush=0.9
     DecideChance_Scapegoat=0.4
     SpawnChance_BeaconAmmo=0.04
     SpawnChance_SporeAmmo=0.025
     bCoopWeaponMode=True
}
