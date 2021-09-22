class MushMusic extends Info;



simulated function BeginPlay()
{   
    Super.BeginPlay();
    
    if (PlayerPawn(Owner) == None || MushMatchInfo(PlayerPawn(Owner).GameReplicationInfo) == None)
        Destroy();
        
    else {
        PlayerPawn(Owner).ClientSetMusic(MushMatchInfo(PlayerPawn(Owner).GameReplicationInfo).MushDiscoveredMusic, 0, 0, MTRAN_Segue);

        SetTimer(FRand() * 16 + 41, false);
    }
}


simulated function Timer()
{
    if (Level.NetMode != NM_Standalone) { // aka dedicated server
        Log("Stopping discover music.");
    }
    
    PlayerPawn(Owner).ClientSetMusic(Level.Song, Level.SongSection, 0, MTRAN_SlowFade);
    
    Destroy();
}


defaultproperties
{
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
}
