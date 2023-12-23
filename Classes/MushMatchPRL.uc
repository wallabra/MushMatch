class MushMatchPRL extends PlayerReplicationList config(MushMatch);

var bool                            bIsSuspected;
var PlayerReplicationList           SuspectedBy;
var bool                            bMush;
var bool                            bKnownMush, bKnownHuman;
var bool                            bDead, bSpectator;
var int                             InitialTeam;
var float                           ImmuneLevel;
var float                           ImmuneMomentum, ImmuneThrust, ImmuneResistance;
var PlayerReplicationList           HatedBy, HatedByTail;
var class<PlayerReplicationList>    HatePRLType;

// Replicated settings
var float
    ImmuneMomentumDrag,
    ImmuneMomentumThreshold,
    ImmuneNaturalRegen,
    ImmuneNaturalFallback,
    ImmuneNaturalSnapThreshold,
    ImmuneHitAmount,
    InstantImmuneHitFactor,
    ImmuneDangerLevel,
    ImmuneResistLevel,
    ImmuneResistVulnerability;

var bool
    bImmuneNaturallyTendsToFull,
    bImmuneSnap,
    bNoNegativeImmune,
    bNoSuperImmune,
    bImmuneInstantHit;


replication
{
    reliable if (Role == ROLE_Authority)
        bIsSuspected, bMush, bKnownHuman, bKnownMush, bDead, InitialTeam, HatedBy,

        // immune level parameters
        ImmuneMomentumThreshold, ImmuneMomentumDrag,
        ImmuneNaturalRegen, ImmuneNaturalFallback, ImmuneNaturalSnapThreshold, ImmuneHitAmount,
        InstantImmuneHitFactor, ImmuneDangerLevel,

        // immune level configurations
        bImmuneNaturallyTendsToFull, bImmuneSnap,
        bNoNegativeImmune, bNoSuperImmune,
        bImmuneInstantHit,

        SetInitialTeam;

    // Immune level realtime updates should be cautious.

    reliable if (Role == ROLE_Authority && PlayerPawn(Owner.Owner) != None)
        ImmuneThrust;

    unreliable if (Role == ROLE_Authority)
        ImmuneLevel, ImmuneResistance, ImmuneMomentum;
}


simulated function BeginPlay() {
    Super.BeginPlay();

    if (Role == ROLE_Authority) {
        UpdateConfigVars();
    }
}

// Update configuration from the MushMatch(Level.Game).
function UpdateConfigVars() {
    local MushMatch MM;
    MM = MushMatch(Level.Game);

    if (MM == None) {
        // rip
        Warn(class.name@"detected outside a Mush Match; gameinfo is"@Level.Game);
        return;
    }

    ImmuneMomentumDrag          = MM.ImmuneMomentumDrag;
    ImmuneMomentumThreshold     = MM.ImmuneMomentumThreshold;
    ImmuneNaturalRegen          = MM.ImmuneNaturalRegen;
    ImmuneNaturalFallback       = MM.ImmuneNaturalFallback;
    ImmuneNaturalSnapThreshold  = MM.ImmuneNaturalSnapThreshold;
    ImmuneHitAmount             = MM.ImmuneHitAmount;
    InstantImmuneHitFactor      = MM.InstantImmuneHitFactor;
    ImmuneDangerLevel           = MM.ImmuneDangerLevel;

    bImmuneNaturallyTendsToFull = MM.bImmuneNaturallyTendsToFull;
    bImmuneSnap                 = MM.bImmuneSnap;
    bNoNegativeImmune           = MM.bNoNegativeImmune;
    bNoSuperImmune              = MM.bNoSuperImmune;
    bImmuneInstantHit           = MM.bImmuneInstantHit;
    ImmuneResistLevel           = MM.ImmuneResistLevel;
    ImmuneResistVulnerability   = MM.ImmuneResistVulnerability;

    ImmuneResistance = ImmuneResistLevel;
}

simulated event Tick(float TimeDelta) {
    ImmuneMomentum += ImmuneThrust;
    ImmuneThrust = 0.0;

    if (Abs(ImmuneMomentum) >= ImmuneMomentumThreshold) {
        ImmuneLevel += ImmuneMomentum * TimeDelta;

        if (ImmuneLevel < 0.0 && bNoNegativeImmune) {
            ImmuneLevel = 0.0;
        }

        if (ImmuneLevel > 1.0 && bNoSuperImmune) {
            ImmuneLevel = 1.0;
        }

        ImmuneMomentum -= ImmuneMomentum * TimeDelta * ImmuneMomentumDrag;

        if (Abs(ImmuneMomentum) < ImmuneMomentumThreshold) {
            ImmuneMomentum = 0.0;
        }
    }

    if (bImmuneNaturallyTendsToFull) {
        if (Abs(ImmuneLevel - 1.0) < ImmuneNaturalSnapThreshold) {
            if (ImmuneMomentum == 0.0 && bImmuneSnap) {
                ImmuneLevel = 1.0;
            }
        }

        else if (ImmuneLevel < 1.0) {
            ImmuneLevel += ImmuneNaturalRegen * TimeDelta;
        }

        else if (!bNoSuperImmune) {
            ImmuneLevel -= ImmuneNaturalFallback * TimeDelta;
        }
    }
}

function PostBeginPlay() {
    // Assert Owner is a PlayerReplicationInfo.
    if (PlayerReplicationInfo(Owner) == None) {
        Log(self@"is not owned by a PlayerReplicationInfo! Owner:"@Owner);
        return;
    }

    InitialTeam = int(bMush);
}

simulated function ImmuneHit(float Amount) {
    ImmuneThrust -= Amount / ImmuneResistance;

    // Also decrease immune-resistance a little
    if (ImmuneResistance > 1.0) {
        ImmuneResistance = 1.0 + (ImmuneResistance - 1.0) / Sqrt(Amount / (ImmuneResistVulnerability - 1.0));
    }
}

function UpdateImmune(float Immune) {
    ImmuneLevel = Immune;
}

function TryToMush(Pawn Instigator) {
    local Pawn mushed;

    if (Role != ROLE_Authority) {
        return;
    }

    // Get Pawn owner, and do sanity checks

    mushed = Pawn(Owner.Owner);

    if (mushed == None) {
        Warn("Could not find Pawn who is the Owner of the PlayerReplicationInfo that should in turn be" @self@ "'s owner!");
        return;
    }

    // Check if immune is to be lowered instantly

    if (bImmuneInstantHit) {
        UpdateImmune(ImmuneLevel - ImmuneHitAmount * InstantImmuneHitFactor);
    }

    // Check if immune level low enough for mushing

    if (ImmuneLevel <= ImmuneDangerLevel) {
        MushMatch(Level.Game).MakeMush(mushed, Instigator);
        return;
    }

    // If not, just take it as an immune hit

    if (!bImmuneInstantHit) {
        ImmuneHit(1.0);
        return;
    }
}

simulated event bool HasHate(PlayerReplicationInfo Other)
{
    if (HatedBy == None)
        return false;

    return HatedBy.FindPlayer(Other) != None;
}

simulated event bool HasHateOnPlayer(PlayerReplicationInfo Other)
{
    local MushMatchPRL OtherMPRL;

    OtherMPRL = MushMatchPRL(Root.FindPlayer(Other));

    return HasHateOnPRL(OtherMPRL);
}

simulated event bool HasHateOnPRL(MushMatchPRL Other)
{
    if (Other == None || Other.HatedBy == None)
        return false;

    return Other.HatedBy.FindPlayer(PlayerReplicationInfo(Owner)) != None;
}


simulated event bool HasAnyHate()
{
    return HatedBy != None;
}

simulated event AddHate(PlayerReplicationInfo Other)
{
    if ( HatedBy == None ) {
        HatedBy = Other.Spawn(HatePRLType, Other);
        HatedBy.Root = HatedBy;
        HatedByTail = HatedBy;
    }

    else {
        HatedBy.AppendPlayer(Other, HatedByTail, HatePRLType);
    }
}

simulated event bool RemoveHate(PlayerReplicationInfo Other)
{
    local PlayerReplicationList newTail;

    if ( HatedBy == None )
        return false;

    else {
        newTail = HatedByTail;
        return HatedBy.RemovePlayer(Other, HatedBy, newTail);
        HatedByTail = newTail;
    }
}

simulated event SetInitialTeam() {
    InitialTeam = int(bMush);
}


defaultproperties
{
    bIsSuspected=false
    bKnownMush=false
    bKnownHuman=false
    bDead=false
    bSpectator=false
    bMush=false
    HatedBy=none
    InitialTeam=0
    ImmuneLevel=1.0
    ImmuneMomentum=0.0
    HatePRLType=class'PlayerReplicationList'
}
