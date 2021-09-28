class ArenaMush extends Mutator;


function bool IsRelevant(Actor Other, out byte bSuperRelevant)
{
    if ( Sporifier(Other) != None || SporeCanister(Other) != None || MushBeacon(Other) != None || MushBeaconAmmo(Other) != None )
        return true;

    return Super.IsRelevant(Other, bSuperRelevant);
}
