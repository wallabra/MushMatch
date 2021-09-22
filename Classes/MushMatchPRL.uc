class MushMatchPRL extends PlayerReplicationList;

var bool                    bIsSuspected;
var bool                    bKnownMush;
var bool                    bKnownHuman;
var bool                    bDead;
var PlayerReplicationlist   HatedBy;


replication
{
    reliable if (Role == ROLE_Authority)
        bIsSuspected, bKnownHuman, bKnownMush, bDead, HatedBy;
}


simulated event bool HasHate(PlayerReplicationInfo Other)
{
    if (HatedBy == None)
        return false;

    return HatedBy.FindPlayer(Other) != None;
}

simulated event bool HasAnyHate()
{
    return HatedBy != None;
}

simulated event AddHate(PlayerReplicationInfo Other)
{
    if ( HatedBy == None ) {
        HatedBy = Other.Spawn(class'PlayerReplicationList', Other);
    }
    
    else {
        HatedBy.AppendPlayer(Other);
    }
}

simulated event bool RemoveHate(PlayerReplicationInfo Other)
{
    if ( HatedBy == None )
        return false;

    else {
        return HatedBy.RemovePlayer(Other, HatedBy);
    }
}


defaultproperties
{
    bIsSuspected=false
    bKnownMush=false
    bKnownHuman=false
    bDead=false
    HatedBy=none
}
