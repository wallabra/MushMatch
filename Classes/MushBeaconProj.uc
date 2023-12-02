#exec mesh import mesh=MBeaconProj anivfile=Models\MBeaconProj_a.3d datafile=Models\MBeaconProj_d.3d x=0 y=0 z=0 mlod=1

#exec mesh sequence mesh=MBeaconProj seq=All startframe=0 numframes=1 rate=1
#exec mesh sequence mesh=MBeaconProj seq=Still startframe=0 numframes=1 rate=1

#exec meshmap new meshmap=MBeaconProj mesh=MBeaconProj
#exec meshmap scale meshmap=MBeaconProj x=0.1 y=0.1 z=0.2

#exec texture import name=JMBeaconProj file=Textures\JMBeaconProj.pcx group=Skins
#exec meshmap settexture meshmap=MBeaconProj num=0 texture=JMBeaconProj

class MushBeaconProj extends Projectile;

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();

    SetPhysics(PHYS_Projectile);
    Velocity = Vector(Rotation) * speed;
}

simulated function Tick(float TimeDelta)
{
    local Rotator r;

    Super.Tick(TimeDelta);

    SetRotation(Rotator(Velocity));

    r = Rotation;
    r.Roll += TimeDelta * 65536;

    SetRotation(r);
}

function ProcessTouch(Actor Other, Vector HitLocation)
{
    if ( Other == None || Pawn(Other) == None || !Pawn(Other).bIsPlayer || Instigator == None || !Instigator.bIsPlayer || Instigator == Other )
        return;

    if (MushMatch(Level.Game) == None || MushMatchInfo(Level.Game.GameReplicationInfo) == None) {
        Warn(self @"is in a non-MushMatch game!");
        return;
    }

    if ( Pawn(Other).bIsPlayer && Pawn(Other).PlayerReplicationInfo != None && Pawn(Other).Health > 0 )
    {
        MushMatch(Level.Game).StrapBeacon(Pawn(Other), Instigator);
    }

    Destroy();
}

defaultproperties
{
     speed=1400.000000
     MaxSpeed=1400.000000
     ImpactSound=Sound'Botpack.Pickups.AmmoPick'
     RemoteRole=ROLE_SimulatedProxy
     Mesh=LodMesh'MBeaconProj'
     DrawScale=0.450000
     CollisionRadius=10.000000
     CollisionHeight=12.000000
}
