package steamwrap;
import cpp.Lib;
import steamwrap.SteamWrap.LeaderboardScore;

private enum LeaderboardOp
{
	FIND(id:String);
	UPLOAD(score:LeaderboardScore);
	DOWNLOAD(id:String, requestType:LeaderboardRequestType, start:Int, end:Int);
}

enum LeaderboardRequestType
{
	Global; // "start" and "end" are absolutes
	GlobalAroundUser; // "start" and "end" are relative; ie. "start -2", "end 2" will retrieve 2 before, 2 after
	Friends; // "start" and "end" are ignored
}

enum NotificationPosition
{
	TopLeft;
	TopRight;
	BottomLeft;
	BottomRight;
}

class SteamWrap
{
	public static var active(default,null):Bool = false;
	public static var wantQuit(default,null):Bool = false;

	public static var whenAchievementStored:String->Void;
	public static var whenLeaderboardScoresDownloaded:Array<LeaderboardScore>->Void;
	public static var whenLeaderboardScoreUploaded:LeaderboardScore->Void;
	public static var whenTrace:String->Void;

	static var haveGlobalStats:Bool;
	static var haveReceivedUserStats:Bool;
	static var wantStoreStats:Bool;
	static var appId:Int;

	static var leaderboardIds:Array<String>;
	static var leaderboardOps:List<LeaderboardOp>;
	
	public static function init(appId_:Int)
	{
		#if cpp
		if (active) return;
		
		appId = appId_;
		leaderboardIds = new Array<String>();
		leaderboardOps = new List<LeaderboardOp>();

		try
		{
			SteamWrap_Init = cpp.Lib.load("steamwrap", "SteamWrap_Init", 1);
			SteamWrap_Shutdown = cpp.Lib.load("steamwrap", "SteamWrap_Shutdown", 0);
			SteamWrap_RunCallbacks = cpp.Lib.load("steamwrap", "SteamWrap_RunCallbacks", 0);
			SteamWrap_SetNotificationPosition = cpp.Lib.load("steamwrap", "SteamWrap_SetNotificationPosition", 1);
			SteamWrap_GetUserID64 = cpp.Lib.load("steamwrap", "SteamWrap_GetUserID64", 0);
			SteamWrap_GetUsername = Lib.load("steamwrap", "SteamWrap_GetUsername", 0);
			SteamWrap_RequestStats = cpp.Lib.load("steamwrap", "SteamWrap_RequestStats", 0);
			SteamWrap_GetStat = cpp.Lib.load("steamwrap", "SteamWrap_GetStat", 1);
			SteamWrap_SetStat = cpp.Lib.load("steamwrap", "SteamWrap_SetStat", 2);
			SteamWrap_SetAchievement = cpp.Lib.load("steamwrap", "SteamWrap_SetAchievement", 1);
			SteamWrap_ClearAchievement = cpp.Lib.load("steamwrap", "SteamWrap_ClearAchievement", 1);
			SteamWrap_IndicateAchievementProgress = cpp.Lib.load("steamwrap", "SteamWrap_IndicateAchievementProgress", 3);
			SteamWrap_StoreStats = cpp.Lib.load("steamwrap", "SteamWrap_StoreStats", 0);
			SteamWrap_FindLeaderboard = cpp.Lib.load("steamwrap", "SteamWrap_FindLeaderboard", 1);
			SteamWrap_GetLeaderboardEntryCount = cpp.Lib.load("steamwrap", "SteamWrap_GetLeaderboardEntryCount", 1);
			SteamWrap_UploadScore = cpp.Lib.load("steamwrap", "SteamWrap_UploadScore", 3);
			SteamWrap_DownloadScores = cpp.Lib.load("steamwrap", "SteamWrap_DownloadScores", 4);
			SteamWrap_RequestGlobalStats = cpp.Lib.load("steamwrap", "SteamWrap_RequestGlobalStats", 0);
			SteamWrap_GetGlobalStat = cpp.Lib.load("steamwrap", "SteamWrap_GetGlobalStat", 1);
			SteamWrap_RestartAppIfNecessary = cpp.Lib.load("steamwrap", "SteamWrap_RestartAppIfNecessary", 1);
			SteamWrap_IsSteamRunning = cpp.Lib.load("steamwrap", "SteamWrap_IsSteamRunning", 0);
		}
		catch (e:Dynamic)
		{
			customTrace("Running non-Steam version (" + e + ")");
			return;
		}

		// if we get this far, the dlls loaded ok and we need Steam to init.
		// otherwise, we're trying to run the Steam version without the Steam client
		active = SteamWrap_Init(steamWrap_onEvent);

		if (active)
		{
			customTrace("Steam active");
			SteamWrap_RequestStats();
			SteamWrap_RequestGlobalStats();
		}
		else
		{
			customTrace("Steam failed to activate");
			// restart under Steam
			wantQuit = true;
		}
		#end
	}

	public static function shutdown()
	{
		if (!active) return;
		SteamWrap_Shutdown();
	}

	public static function isSteamRunning()
	{
		return SteamWrap_IsSteamRunning();
	}

	public static function restartAppInSteam()
	{
		return SteamWrap_RestartAppIfNecessary(appId);
	}

	private static inline function customTrace(str:String)
	{
		if (whenTrace != null)
			whenTrace(str);
		else
			trace(str);
	}

	private static inline function report(func:String, params:Array<String>, result:Bool):Bool
	{
		var str = "[STEAM] " + func + "(" + params.join(",") + ") " + (result ? " SUCCEEDED" : " FAILED");
		customTrace(str);
		return result;
	}

	public static function setNotificationPosition(notifyPos:NotificationPosition):Bool
	{
		return active && report("setNotificationPosition", [Type.enumConstructor(notifyPos)], SteamWrap_SetNotificationPosition(Type.enumIndex(notifyPos)));
	}
	
	public static function getUserID64():String
	{
		if (!active) return "";
		
		var userID:String = SteamWrap_GetUserID64();
		report("getUserID64", [], userID.length > 0);
		return userID;
	}
	
	public static function getUsername():String
	{
		if (!active) return "";
		
		var username:String = SteamWrap_GetUsername();
		report("getUsername", [], username.length > 0);
		return username;
	}
	
	public static function setAchievement(id:String):Bool
	{
		return active && report("setAchievement", [id], SteamWrap_SetAchievement(id));
	}

	public static function clearAchievement(id:String):Bool
	{
		return active && report("clearAchievement", [id], SteamWrap_ClearAchievement(id));
	}

	public static function indicateAchievementProgress(id:String, curProgress:Int, maxProgress:Int):Bool
	{
		return active && report("indicateAchivevementProgress", [id, Std.string(curProgress), Std.string(maxProgress)], SteamWrap_IndicateAchievementProgress(id, curProgress, maxProgress));
	}

	// Kinda awkwardly returns 0 on errors and uses 0 for checking success
	public static function getStat(id:String):Int
	{
		if (!active)
			return 0;
		var val = SteamWrap_GetStat(id);
		report("getStat", [id], val != 0);
		return val;
	}

	public static function setStat(id:String, val:Int):Bool
	{
		return active && report("setStat", [id, Std.string(val)], SteamWrap_SetStat(id, val));
	}

	public static function getStat(id:String):Int
	{
		if (!active) {
			return -1;
		}

		var val = SteamWrap_GetStat(id);
		report("getStat", [id], val != 0);
		return val;
	}

	public static function storeStats():Bool
	{
		return active && report("storeStats", [], SteamWrap_StoreStats());
	}

	private static function findLeaderboardIfNecessary(id:String)
	{
		if (!Lambda.has(leaderboardIds, id) && !Lambda.exists(leaderboardOps, function(op) { return Type.enumEq(op, FIND(id)); }))
		{
			leaderboardOps.add(LeaderboardOp.FIND(id));
		}
	}

	// This becomes valid once a score completes uploading to or downloading from the specified leaderboard. Until then, it will return 0.
	public static function getLeaderboardEntryCount(id:String):Int
	{
		if (!active)
			return 0;
		var val = SteamWrap_GetLeaderboardEntryCount(id);
		report("getLeaderboardEntryCount", [id], val != 0);
		return val;
	}
	
	public static function uploadLeaderboardScore(score:LeaderboardScore):Bool
	{
		if (!active) return false;
		var startProcessingNow = (leaderboardOps.length == 0);
		findLeaderboardIfNecessary(score.leaderboardId);
		leaderboardOps.add(LeaderboardOp.UPLOAD(score));
		if (startProcessingNow) processNextLeaderboardOp();
		return true;
	}

	public static function downloadLeaderboardScores(leaderboardId:String, requestType:LeaderboardRequestType, start:Int, end:Int):Bool
	{
		if (!active) return false;
		var startProcessingNow = (leaderboardOps.length == 0);
		findLeaderboardIfNecessary(leaderboardId);
		leaderboardOps.add(LeaderboardOp.DOWNLOAD(leaderboardId, requestType, start, end));
		if (startProcessingNow) processNextLeaderboardOp();
		return true;
	}

	private static function processNextLeaderboardOp()
	{
		var op = leaderboardOps.pop();
		if (op == null) return;

		switch (op)
		{
			case FIND(id):
				if (!report("Leaderboard.FIND", [id], SteamWrap_FindLeaderboard(id)))
					processNextLeaderboardOp();
			case UPLOAD(score):
				if (!report("Leaderboard.UPLOAD", [score.toString()], SteamWrap_UploadScore(score.leaderboardId, score.score, [score.details.length].concat(score.details))))
					processNextLeaderboardOp();
			case DOWNLOAD(id, requestType, start, end):
				if (!report("Leaderboard.DOWNLOAD", [id, Type.enumConstructor(requestType), Std.string(start), Std.string(end)], SteamWrap_DownloadScores(id, Type.enumIndex(requestType), start, end)))
					processNextLeaderboardOp();
		}
	}

	public static function onEnterFrame()
	{
		if (!active) return;
		SteamWrap_RunCallbacks();

		if (wantStoreStats)
		{
			wantStoreStats = false;
			SteamWrap_StoreStats();
		}
	}

	private static function steamWrap_onEvent(e:Dynamic)
	{
		var type:String = Std.string(Reflect.field(e, "type"));
		var success:Bool = (Std.int(Reflect.field(e, "success")) != 0);
		var data:String = Std.string(Reflect.field(e, "data"));

		customTrace("[STEAM] " + type + (success ? " SUCCESS" : " FAIL") + " (" + data + ")");

		switch (type)
		{
			case "UserStatsReceived":
				haveReceivedUserStats = success;
			
			case "UserStatsStored":
				// retry next frame if failed
				wantStoreStats = !success;

			case "UserAchievementStored":
				if (whenAchievementStored != null) whenAchievementStored(data);

			case "GlobalStatsReceived":
				haveGlobalStats = success;

			case "LeaderboardFound":
				if (success)
				{
					leaderboardIds.push(data);
				}
				processNextLeaderboardOp();
			case "ScoreDownloaded":
				if (success)
				{
					var scores:Array<LeaderboardScore> = new Array<LeaderboardScore>();
					if ( data.length > 0 )
					{
						var scoresTxt:Array<String> = data.split(";");
						for (scoreTxt in scoresTxt)
						{
							var score:LeaderboardScore = LeaderboardScore.fromString(scoreTxt);
							scores.push(score);
						}
					}
					if (whenLeaderboardScoresDownloaded != null) whenLeaderboardScoresDownloaded(scores);
				}
				processNextLeaderboardOp();
			case "ScoreUploaded":
				if (success)
				{
					var score = LeaderboardScore.fromString(data);
					if (score != null && whenLeaderboardScoreUploaded != null) whenLeaderboardScoreUploaded(score);
				}
				processNextLeaderboardOp();
		}
	}

	private static var SteamWrap_Init:Dynamic;
	private static var SteamWrap_Shutdown:Dynamic;
	private static var SteamWrap_SetNotificationPosition:Dynamic;
	private static var SteamWrap_RunCallbacks:Dynamic;
	private static var SteamWrap_GetUserID64:Void->String;
	private static var SteamWrap_GetUsername:Void->String;
	private static var SteamWrap_RequestStats:Dynamic;
	private static var SteamWrap_GetStat:Dynamic;
	private static var SteamWrap_SetStat:Dynamic;
	private static var SteamWrap_SetAchievement:Dynamic;
	private static var SteamWrap_ClearAchievement:Dynamic;
	private static var SteamWrap_IndicateAchievementProgress:Dynamic;
	private static var SteamWrap_StoreStats:Dynamic;
	private static var SteamWrap_FindLeaderboard:Dynamic;
	private static var SteamWrap_GetLeaderboardEntryCount:String->Int;
	private static var SteamWrap_UploadScore:String->Int->Array<Int>->Bool;
	private static var SteamWrap_DownloadScores:String->Int->Int->Int->Bool;
	private static var SteamWrap_RequestGlobalStats:Dynamic;
	private static var SteamWrap_GetGlobalStat:Dynamic;
	private static var SteamWrap_RestartAppIfNecessary:Dynamic;
	private static var SteamWrap_IsSteamRunning:Dynamic;
}

class LeaderboardScore
{
	public var leaderboardId:String;
	public var playerName:String;
	public var score:Int;
	public var details:Array<Int>;
	public var rank:Int;
	
	public function new(leaderboardId_:String, playerName_:String, score_:Int, detail_:Int, rank_:Int=-1)
	{
		leaderboardId = leaderboardId_;
		playerName = playerName_;
		score = score_;
		details = [detail_];
		rank = rank_;
	}

	public function setExtraDetail(detailPos_:Int, detailVal_:Int):Bool
	{
		if (detailPos_ < 0 || detailPos_ > 63)
		{
			return false;
		}
	
		while (details.length < detailPos_)
		{
			details.push(0);
		}
		
		details[detailPos_] = detailVal_;
		
		return true;
	}
	
	public function toString():String
	{
		return leaderboardId  + "," + playerName + "," + score + "," + rank + "," + details.length + "," + details.join(",");
	}

	public static function fromString(str:String):LeaderboardScore
	{
		var tokens = str.split(",");
		
		if (tokens.length < 6 || tokens.length != 5 + Std.parseInt(tokens[4]))
		{
			return null;
		}
		
		var entry:LeaderboardScore = new LeaderboardScore(tokens[0], tokens[1], Std.parseInt(tokens[2]), Std.parseInt(tokens[5]), Std.parseInt(tokens[3]));
		for (i in 6...tokens.length)
		{
			entry.setExtraDetail(i - 5, Std.parseInt(tokens[i]));
		}
		
		return entry;
	}
}
