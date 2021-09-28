#exec mesh import mesh=MBeaconAmmo anivfile=Models\MBeaconAmmo_a.3d datafile=Models\MBeaconAmmo_d.3d x=0 y=0 z=0 mlod=1
#exec mesh scale mesh=MBeaconAmmo x=1 y=1 z=1

#exec mesh sequence mesh=MBeaconAmmo seq=All startframe=0 numframes=1 rate=1
#exec mesh sequence mesh=MBeaconAmmo seq=Still startframe=0 numframes=1 rate=1

#exec meshmap new meshmap=MBeaconAmmo mesh=MBeaconAmmo
#exec meshmap scale meshmap=MBeaconAmmo x=0.1 y=0.1 z=0.2

#exec texture import name=JMBeaconAmmo file=Textures\JMBeaconAmmo.pcx group=Skins
#exec meshmap settexture meshmap=MBeaconAmmo num=0 texture=JMBeaconAmmo

class MushBeaconAmmo extends TournamentAmmo;

defaultproperties
{
     AmmoAmount=3
     MaxAmmo=20
     PickupMessage="You got some Mush Beacons."
     ItemName="Spore Canister"
     PickupViewMesh=LodMesh'MBeaconAmmo'
     PickupViewScale=3.500000
     Physics=PHYS_Falling
     Mesh=LodMesh'MBeaconAmmo'
     CollisionRadius=12.000000
     CollisionHeight=24.000000
}
