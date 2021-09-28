class PlayerReplicationList extends ReplicationInfo;

var PlayerReplicationList Next, Root;


replication
{
    reliable if (Role == ROLE_Authority)
        Next, Root;
}


simulated function PlayerReplicationList AppendPlayer(PlayerReplicationInfo other, optional class<PlayerReplicationList> PRLType)
{
    local PlayerReplicationList prl;

    if (PRLType == None)
        PRLType = class;

    for ( prl = self; prl.Next != None; prl = prl.Next );
    
    prl.Next = Spawn(PRLType, other);
    prl.Root = Root;
    return prl.Next;
}

simulated function PlayerReplicationList FindPlayer(PlayerReplicationInfo other)
{
    local PlayerReplicationList prl;

    for ( prl = self; prl != None; prl = prl.Next ) if ( prl.owner == other ) return prl;
    
    return None;
}

simulated function bool RemovePlayer(PlayerReplicationInfo other, out PlayerReplicationList newRoot)
{
    local PlayerReplicationList prl, prev;

    if (Owner == Other) {
        if (newRoot == Self) {
            newRoot = Next;

            // update everyone's roots
            for (prl = Next; prl != None; prl = prl.Next) {
                prl.Root = Next;
            }
        }
            
        Destroy();

        return True;
    }

    for ( prl = self; prl != None && prl.Owner != other; prl = prl.Next )
        prev = prl;
    
    if ( prl == None ) return False;
    
    if (newRoot == prl)
        newRoot = prl.Next;
        
    prev.Next = prl.Next;
    prl.Destroy();
    
    return True;
}


defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    Next=None
    Root=None
}
