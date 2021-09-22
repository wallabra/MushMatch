class PlayerReplicationList extends ReplicationInfo;

var PlayerReplicationList next;


replication
{
    reliable if (Role == ROLE_Authority)
        next;
}


simulated function PlayerReplicationList AppendPlayer(PlayerReplicationInfo other, optional class<PlayerReplicationList> PRLType)
{
    local PlayerReplicationList prl;

    if (PRLType == None)
        PRLType = class;

    for ( prl = self; prl.next != None; prl = prl.next );
    
    prl.next = Spawn(PRLType, other);
    return prl.next;
}

simulated function PlayerReplicationList FindPlayer(PlayerReplicationInfo other)
{
    local PlayerReplicationList prl;

    for ( prl = self; prl != None; prl = prl.next ) if ( prl.owner == other ) return prl;
    
    return None;
}

simulated function bool RemovePlayer(PlayerReplicationInfo other, out PlayerReplicationList newRoot)
{
    local PlayerReplicationList prl, prev;

    if (Owner == Other) {
        if (newRoot == Self)
            newRoot = next;
            
        Destroy();

        return True;
    }

    for ( prl = self; prl != None && prl.Owner != other; prl = prl.next )
        prev = prl;
    
    if ( prl == None ) return False;
    
    if (newRoot == prl)
        newRoot = prl.next;
        
    prev.next = prl.next;
    prl.Destroy();
    
    return True;
}


defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    next=None
}
