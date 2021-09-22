class MushMatchScoreBoard extends TournamentScoreBoard;


var localized string StatusString, TeamString;


// slightly modified version of Super.DrawNameAndPing
// that does not draw frags, as those are possibly
// incriminating
function DrawNameAndPing(Canvas Canvas, PlayerReplicationInfo PRI, float XOffset, float YOffset, bool bCompressed)
{
    local float XL, YL, XL2, YL2, XL3, YL3;
    local bool bLocalPlayer;
    local PlayerPawn PlayerOwner;
    local int Time;
    local string Status, Team;
    local MushMatchPRL PPRL;
    
    if (PRI.Team == 254) return; // don't render the Strawman
    if (PRI.Team == 253) return; // don't render spectators

    Status = MushMatchInfo(PlayerPawn(Owner).GameReplicationInfo).TeamTextStatus(PRI, PlayerPawn(Owner));
    Team = MushMatchInfo(PlayerPawn(Owner).GameReplicationInfo).TeamTextAlignment(PRI, PlayerPawn(Owner));
    
    PPRL = MushMatchPRL(MushMatchInfo(PlayerPawn(Owner).GameReplicationInfo).PRL.FindPlayer(PRI));

    PlayerOwner = PlayerPawn(Owner);

    bLocalPlayer = (PRI.PlayerName == PlayerOwner.PlayerReplicationInfo.PlayerName);
    Canvas.Font = MyFonts.GetBigFont(Canvas.ClipX);

    // Draw Name
    if ( PRI.bAdmin )
        Canvas.DrawColor = WhiteColor;
    else if ( bLocalPlayer ) 
        Canvas.DrawColor = GoldColor;
    else 
        Canvas.DrawColor = CyanColor;

    Canvas.SetPos(Canvas.ClipX * 0.1875, YOffset);
    Canvas.DrawText(PRI.PlayerName, False);

    Canvas.StrLen( "0000", XL, YL );

    if ( !bLocalPlayer )
        Canvas.DrawColor = LightCyanColor;

    if ( !bCompressed && PlayerPawn(Owner).GameReplicationInfo != None )
    {
        // Draw Status
        Canvas.StrLen(Status, XL2, YL);
        Canvas.SetPos(Canvas.ClipX * 0.625 + XL * 0.5 - XL2, YOffset);
        Canvas.DrawText(Status, false);

        // Draw Team
        Canvas.StrLen(Team, XL2, YL);
        Canvas.SetPos(Canvas.ClipX * 0.75 + XL * 0.5 - XL2, YOffset);
        Canvas.DrawText(Team, false);
    }

    if ( (Canvas.ClipX > 512) && (Level.NetMode != NM_Standalone) )
    {
        Canvas.DrawColor = WhiteColor;
        Canvas.Font = MyFonts.GetSmallestFont(Canvas.ClipX);

        // Draw Time
        Time = Max(1, (Level.TimeSeconds + PlayerOwner.PlayerReplicationInfo.StartTime - PRI.StartTime)/60);
        Canvas.TextSize( TimeString$": 999", XL3, YL3 );
        Canvas.SetPos( Canvas.ClipX * 0.75 + XL, YOffset );
        Canvas.DrawText( TimeString$":"@Time, false );

        // Draw FPH
        Canvas.TextSize( FPHString$": 999", XL2, YL2 );
        Canvas.SetPos( Canvas.ClipX * 0.75 + XL, YOffset + 0.5 * YL );
        Canvas.DrawText( FPHString$": "@int(60 * PRI.Score/Time), false );

        XL3 = FMax(XL3, XL2);
        // Draw Ping
        Canvas.SetPos( Canvas.ClipX * 0.75 + XL + XL3 + 16, YOffset );
        Canvas.DrawText( PingString$":"@PRI.Ping, false );
    }
}

function DrawCategoryHeaders(Canvas Canvas)
{
    local float Offset, XL, YL;

    Offset = Canvas.CurY;
    Canvas.DrawColor = WhiteColor;

    Canvas.StrLen(PlayerString, XL, YL);
    Canvas.SetPos((Canvas.ClipX / 8)*2 - XL/2, Offset);
    Canvas.DrawText(PlayerString);

    Canvas.StrLen(TeamString, XL, YL);
    Canvas.SetPos((Canvas.ClipX / 8)*5 - XL/2, Offset);
    Canvas.DrawText(StatusString);

    Canvas.StrLen(StatusString, XL, YL);
    Canvas.SetPos((Canvas.ClipX / 8)*6 - XL/2, Offset);
    Canvas.DrawText(TeamString);
}

// slightly modified version of Super.ShowScores
// that skips the strawman (PRI team 254)

function ShowScores( canvas Canvas )
{
    local PlayerReplicationInfo PRI;
    local int PlayerCount, i;
    local float XL, YL;
    local float YOffset, YStart;
    local font CanvasFont;

    Canvas.Style = ERenderStyle.STY_Normal;

    // Header
    Canvas.SetPos(0, 0);
    DrawHeader(Canvas);

    // Wipe everything.
    for ( i=0; i<ArrayCount(Ordered); i++ )
        Ordered[i] = None;
        
    for ( i=0; i<32; i++ )
    {
        if (PlayerPawn(Owner).GameReplicationInfo.PRIArray[i] != None)
        {
            PRI = PlayerPawn(Owner).GameReplicationInfo.PRIArray[i];
            if ( (!PRI.bIsSpectator || PRI.bWaitingPlayer) && PRI.Team != 254 )
            {
                Ordered[PlayerCount] = PRI;
                PlayerCount++;
                if ( PlayerCount == ArrayCount(Ordered) )
                    break;
            }
        }
    }

    // -- don't sort, that would be potentially incriminating -- {
    // SortScores(PlayerCount);
    // }

    CanvasFont = Canvas.Font;
    Canvas.Font = MyFonts.GetBigFont(Canvas.ClipX);

    Canvas.SetPos(0, 160.0/768.0 * Canvas.ClipY);
    DrawCategoryHeaders(Canvas);

    Canvas.StrLen( "TEST", XL, YL );
    YStart = Canvas.CurY;
    YOffset = YStart;
    if ( PlayerCount > 15 )
        PlayerCount = FMin(PlayerCount, (Canvas.ClipY - YStart)/YL - 1);

    Canvas.SetPos(0, 0);
    for ( I=0; I<PlayerCount; I++ )
    {
        YOffset = YStart + I * YL;
        DrawNameAndPing( Canvas, Ordered[I], 0, YOffset, false );
    }
    Canvas.DrawColor = WhiteColor;
    Canvas.Font = CanvasFont;

    // Trailer
    if ( !Level.bLowRes )
    {
        Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
        DrawTrailer(Canvas);
    }
    Canvas.DrawColor = WhiteColor;
    Canvas.Font = CanvasFont;
}

defaultproperties
{
    StatusString="Status"
    TeamString="Alignment"
}
