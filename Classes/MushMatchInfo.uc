class MushMatchInfo extends TournamentGameReplicationInfo;


replication
{
    reliable if (Role == ROLE_Authority)
        bMushSelected, bMatchEnd, bMatchStart, PRL;
}


var     bool            bMushSelected, bMatchEnd, bMatchStart;
var     MushMatchPRL    PRL;
var     Music           MushDiscoveredMusic;



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
    if (CheckDead(PRI)) {
        if ( PRI.Team == 1 )
            return "Mush (dead)";
            
        if ( PRI.Team == 0 )
            return "Human (dead)";
    }

    if (bMushSelected) {
        if ( Other.PlayerReplicationInfo == PRI || Other.PlayerReplicationInfo.Team == 1 || bMatchEnd || CheckDead(Other.PlayerReplicationInfo) ) {
            if ( PRI.Team == 1 ) {
                if ( CheckBeacon(PRI) )
                    return "Mush (susp.)";
                
                if ( !CheckConfirmedMush(PRI) )
                    return "Mush (unk.)";
            }
                
            else if ( PRI.Team == 0 ) {	                    
                if ( CheckConfirmedHuman(PRI) )
                    return "Human (cert)";
                    
                else if ( CheckBeacon(PRI) )
                    return "Human (susp.)";
                
                else
                    return "Human";
            }
            
            else
                return "[WTF]";
        }
        
        if ( CheckBeacon(PRI) )
            return "Suspected";
        
        if ( PRI.Team == 0 && CheckConfirmedHuman(PRI) )
            return "Human (cert)";

        if ( PRI.Team == 1 && CheckConfirmedMush(PRI) )
            return "Mush (found)";
        
        if ( CheckBeacon(PRI) && !CheckConfirmedMush(PRI) )
            return "Suspected";
        
        return "Unknown";
    }
    
    return "";
}

simulated event string TeamTextAlignment(PlayerReplicationInfo PRI, PlayerPawn Other)
{
    local MushMatchPRL MPRL;

    if (CheckDead(PRI)) {
        if (PRI.Team == 1) {
            MPRL = FindPRL(PRI);
                        
            if (MPRL != None && PRI.Team == MPRL.InitialTeam) {
                return "Mush";
            }

            else {
                return "* Mush";
            }
        }
            
        if (PRI.Team == 0)
            return "Human";
    }

    if (bMushSelected) {
        if (Other.PlayerReplicationInfo == PRI || Other.PlayerReplicationInfo.Team == 1 || bMatchEnd || CheckDead(Other.PlayerReplicationInfo)) {
            if (PRI.Team == 1) {
                MPRL = FindPRL(PRI);
            
                if (MPRL != None && PRI.Team == MPRL.InitialTeam) {
                    return "Mush";
                }

                else {
                    return "* Mush";
                }
            }
                
            else if ( PRI.Team == 0 ) {
                return "Human";
            }
            
            else {
                return "[WTF]";
            }
        }
        
        if (PRI.Team == 0 && CheckConfirmedHuman(PRI)) {
            return "Human";
        }

        if (PRI.Team == 1 && CheckConfirmedMush(PRI)) {
            return "Mush";
        }
        
        return "Unknown";
    }
    
    return "...";
}

simulated event string TeamTextStatus(PlayerReplicationInfo PRI, PlayerPawn Other)
{
    if (CheckDead(PRI)) {
        return "Dead";
    }

    if (bMushSelected) {
        if ( PRI.Team == 0 && CheckConfirmedHuman(PRI) ) {
            return "Certified";
        }

        if ( PRI.Team == 1 && CheckConfirmedMush(PRI) ) {
            return "Discovered";
        }
        
        if ( CheckBeacon(PRI) ) {
            return "Suspected";
        }
        
        return " - ";
    }
    
    return "...";
}



defaultproperties {
    RemoteRole=ROLE_SimulatedProxy
    bMatchStart=false
    bMatchEnd=false
    bMushSelected=false
}