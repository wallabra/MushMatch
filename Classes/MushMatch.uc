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
var(MushMatch) config float SpawnChance_BeaconAmmo, SpawnChance_SporeAmmo;
var(MushMatch) localized string RTeamNames[2];
var(MUSHMATCH) config float InfectionScoreMultiplier;
var(MUSHMATCH) config bool bPenalizeSameTeamKill;

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

function NotifySpree(Pawn Other, int num)
{
    // Don't notify sprees in the middle of the match.

    if (!bMushSelected) {
        Super.NotifySpree(Other, num);
        return;
    }

    if (bMatchEnd) {
        Super.NotifySpree(Other, num);
        return;
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

function ScoreKill(Pawn Killer, Pawn Other)
{
    local MushMatchPRL KPRL, OPRL;

    KPRL = FindPawnPRL(Killer);
    OPRL = FindPawnPRL(Other);

    if (!bMushSelected) {
        return;
    }

    Super.ScoreKill(Killer, Other);

	if (KPRL != None && OPRL != None && KPRL.bMush == OPRL.bMush && bPenalizeSameTeamKill) {
	    // revert the score reward to a score penalty
	    Killer.PlayerReplicationInfo.Score -= 2;
	}
}

function Killed(Pawn Killer, Pawn Other, name DamageType)
{
    local vector hLoc, hMom;
    local int dmg;

    local MushMatchPRL OPRL;
    
    hLoc = Other.Location;
    hMom = vect(0,0,0);
    dmg = 32767;

    DiscardInventory(Other);

    if (Killer != None && Killer.bIsPlayer) {
        LastTauntTime   = Level.TimeSeconds + 6; // auto-taunts also make it easy to spot killers, disable momentarily
    }

    OPRL = MushMatchInfo(GameReplicationInfo).FindPRL(Other.PlayerReplicationInfo);

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

                for (OPRL = MushMatchInfo(GameReplicationInfo).PRL; OPRL != None; OPRL = MushMatchPRL(OPRL.next)) {
                    Log(" * "@ PlayerReplicationInfo(OPRL.Owner).PlayerName @"("$ OPRL @ OPRL.Owner $ ") - next:"@ OPRL.next);
                }
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

    if (Killer == None || Killer == Other) {
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
    
    if (bMatchEnd) {
        return;
    }

    if (Other.bIsPlayer) {
        Other.PlayerReplicationInfo.Deaths += 1;
    }

    CheckEnd();
}
    
function bool CheckEnd()
{
    local int h, m;

    if (!bMushSelected) {
        return false;
    }

    if (bMatchEnd) {
        return true;
    }
    
    GetAliveTeams(h, m);
        
    if ( h == 0 || m == 0 ) {
        SetEndCams("teamstand");
        return true;
    }
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
                if (!PRL.bMush) {
                    humans += 1;
                }
            
                else {
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
    local MushMatchPRL MPRL;

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
        if (!P.bIsPlayer) continue;
        if (P.PlayerReplicationInfo == None) continue;

        MPRL = FindPawnPRL(P);

        if (MPRL == None) continue;
        if (MPRL.bDead) continue;
        if (Int(MPRL.bMush) != winTeam) continue;
        if (P.PlayerReplicationInfo.Deaths > 0) continue;
        if (RWinner != None && P.PlayerReplicationInfo.Score < RWinner.PlayerReplicationInfo.Score) continue;

        RWinner = P;
    }
    
    for (P = Level.PawnList; P != None; P = P.nextPawn)
    {
        Player = PlayerPawn(P);
        MPRL = FindPawnPRL(P);
        
        if (Player != None && MPRL != None)
        {
            if (!bTutorialGame) {
                PlayWinMessage(Player, (Int(MPRL.bMush) == winTeam));
            }
                
            Player.bBehindView = true;
            
            if (RWinner != None) {
                Player.ViewTarget = RWinner;
            }

            else {
                Player.ViewTarget = Player;
            }
                
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

    OtherPRL = FindPawnPRL(Other);

    if (Suspector != None) {
        SuspectorPRL = FindPawnPRL(Suspector);

        if (SuspectorPRL != None && SuspectorPRL.bMush && SuspectorPRL.bKnownMush) {
            return False;  // known mush can't suspect
        }
    }

    if (OtherPRL != None && OtherPRL.bKnownHuman) {
        return False;  // confirmed humans can't be suspected, only spotted!
    }
        
    bHasBeacon = true;
    
    if (MushMatchInfo(GameReplicationInfo).CheckBeacon(Other.PlayerReplicationInfo)) {
        return False;  // Already has beacon, but for that same reason the act of strapping did not succeed, so False.
    }
    
    if (OtherPRL != None) {
        if (PlayerPawn(Other) != None) {
            PlayerPawn(Other).PlayOwnedSound(sound'Suspected');
        }

        BroadcastSuspected(Suspector.PlayerReplicationInfo, Other.PlayerReplicationInfo);

        OtherPRL.bIsSuspected = True;
        OtherPRL.Instigator = Suspector;
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
    local MushMatchInfo MMI;
    local byte res;

    MMI = MushMatchInfo(GameReplicationInfo);

    res = MMI.MushMatchAssessBotAttitude(aBot, Other);

    if (res == 255) {
        return Super.AssessBotAttitude(aBot, Other);
    }

    return res;
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

function MushMatchPRL FindPawnPRL(Pawn Other) {
    if (Other == None || Other.PlayerReplicationInfo == None) {
        return None;
    }

    return MushMatchInfo(GameReplicationInfo).FindPRL(Other.PlayerReplicationInfo);
}

function MakeMush(Pawn Other, Pawn Instigator) {
    local MushMatchPRL MPRL;

    MPRL = FindPawnPRL(Other);

    if (MPRL == None) {
        Warn("MakeMush could not find MushMatchPRL for"@ Other);
        return;
    }

    SafeGiveSporifier(Other);
    
    MPRL.bMush = true;
    Other.PlayerReplicationInfo.Score *= InfectionScoreMultiplier;
        
    if (MushMatch(Level.Game).CheckEnd()) {
        return;
    }

    if (Instigator != None) {
        Instigator.PlayerReplicationInfo.Score += 1;

        if ( Other.Enemy == Instigator ) UnsetEnemy(Other);
        if ( Other == Instigator.Enemy ) UnsetEnemy(Instigator);
        
        // -- Infections are low-key, don't alert everyone in a newly infected mush's vicinity, that's dumb. -- {
        //     for ( p = Level.PawnList; p != none; p = p.nextPawn )
        //         if ( p.bIsPlayer && p != Other && p.PlayerReplicationInfo != none && p.PlayerReplicationInfo.Deaths <= 0 && p.CanSee(Other) && Other.PlayerReplicationInfo.Team == 1  && p.PlayerReplicationInfo.Team == 0 )
        //             mushmatch(Level.Game).SpotMush(Other, p);
        // }
    }
            
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

    P.PlayerReplicationInfo.Team = 0;

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
        prl.bSpectator = True;
    }

    // select some newcomers to be mush
    else if (bMushSelected && FRand() * MushScarceRatio < 1.0) {
        prl.bMush = true;
        prl.SetInitialTeam();
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
    if (bGameEnded || TotalKills > 0.15 * (NumPlayers + NumBots) || CHSpectator(Other) != None) {
        // the spectator edge case is handled elsewhere
        return true;
    }

    return false;
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
    local MushMatchPRL PRL;
    
    for (p = Level.PawnList; p != none; p = p.NextPawn) {
        if (!p.bIsPlayer) continue;

        PRL = FindPawnPRL(p);

        if (PRL == None) continue;
        if (PRL.bMush) continue;

        i++;
    }

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
    function SelectTraitor() {
        local Pawn Selected, Curr;
        local MushMatchPRL PRL;
        local int NumChoices;

        NumChoices = CountPlayers() - MushCount();

        if (NumChoices == 0) {
            Error("Match has no players [to select to be mush]!");
        }
        
        while (Selected == None) {
            for (Curr = Level.PawnList; Curr != none; Curr = Curr.nextPawn) {
                if (!Curr.bIsPlayer) continue;

                PRL = FindPawnPRL(Curr);

                if (PRL == None) continue;
                if (PRL.bMush) continue;
            
                if (FRand() * NumChoices < 1.0) {
                    Selected = Curr;
                }
            }
        }
                    
        PRL.bMush = true;
        SafeGiveSporifier(Selected);
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
     SpawnChance_BeaconAmmo=0.04
     SpawnChance_SporeAmmo=0.025
     bCoopWeaponMode=True
     InfectionScoreMultiplier=-0.5
     bPenalizeSameTeamKill=true
}
