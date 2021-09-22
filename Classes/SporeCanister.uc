#exec mesh import mesh=SporeCanister anivfile=Models\SporeCanister_a.3d datafile=Models\SporeCanister_d.3d x=0 y=0 z=0 mlod=1
#exec mesh scale mesh=SporeCanister x=1 y=1 z=1

#exec mesh sequence mesh=SporeCanister seq=All startframe=0 numframes=1 rate=1
#exec mesh sequence mesh=SporeCanister seq=Still startframe=0 numframes=1 rate=1

#exec meshmap new meshmap=SporeCanister mesh=SporeCanister
#exec meshmap scale meshmap=SporeCanister x=0.1 y=0.1 z=0.2

#exec texture import name=JSporeCanister file=Textures\JSporeCanister.pcx group=Skins
#exec meshmap settexture meshmap=SporeCanister num=0 texture=JSporeCanister

class SporeCanister extends TournamentAmmo;

defaultproperties
{
     AmmoAmount=22
     MaxAmmo=84
     PickupMessage="You got a Spore Canister to refuel your Sporifier."
     ItemName="Spore Canister"
     PickupViewMesh=LodMesh'SporeCanister'
     PickupViewScale=3.500000
     Physics=PHYS_Falling
     Mesh=LodMesh'SporeCanister'
     CollisionRadius=12.000000
     CollisionHeight=24.000000
}
