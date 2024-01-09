#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

any Native_GB_BanClient(Handle plugin, int numParams)
{
	int adminId = GetNativeCell(1);
	if(adminId <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid adminId index (%d)", adminId);
	}
	int targetId = GetNativeCell(2);
	if(targetId <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid targetId index (%d)", targetId);
	}
	int reason = GetNativeCell(3);
	if(reason <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid reason index (%d)", reason);
	}
	GB_BanReason reasonValue = view_as<GB_BanReason>(reason);
	char duration[32];
	if(GetNativeString(4, duration, sizeof duration) != SP_ERROR_NONE)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid duration, but must be positive integer or 0 for permanent");
	}
	int banType = GetNativeCell(5);
	if(banType != BSBanned && banType != BSNoComm)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid banType, but must be 1: mute/gag  or 2: ban");
	}
	char demoName[128];
	if(GetNativeString(6, demoName, sizeof demoName) != SP_ERROR_NONE)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid demoName");
	}
	int tick = GetNativeCell(7);
	if(StrEqual(demoName, "") && tick <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid tick, but must be positive integer");
	}
	if(!ban(adminId, targetId, reasonValue, duration, banType, demoName, tick))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Ban error ");
	}
	return true;
}

/**
 * ban performs the actual work of sending the ban request to the gbans server
 *
 * NOTE: There is currently no way to set a custom ban reason string
 */
public bool ban(int sourceId, int targetId, GB_BanReason reason, const char[] duration, int banType, const char[] demoName, int tick)
{
	char sourceSid[50];
	if(!GetClientAuthId(sourceId, AuthId_Steam3, sourceSid, sizeof sourceSid, true))
	{
		ReplyToCommand(sourceId, "Failed to get sourceId of user: %d", sourceId);
		return false;
	}
	char targetSid[50];
	if(!GetClientAuthId(targetId, AuthId_Steam3, targetSid, sizeof targetSid, true))
	{
		ReplyToCommand(sourceId, "Failed to get targetId of user: %d", targetId);
		return false;
	}

	JSONObject obj = new JSONObject();
	obj.SetString("source_id", sourceSid);
	obj.SetString("target_id", targetSid);
	obj.SetString("note", "");
	obj.SetString("reason_text", "");
	obj.SetInt("ban_type", banType);
	obj.SetInt("reason", view_as<int>(reason));
	obj.SetString("duration", duration);
	obj.SetInt("report_id", 0);
	obj.SetString("demo_name", demoName);
	obj.SetInt("demo_tick", tick);

	char url[1024];
	makeURL("/api/sm/bans/steam/create", url, sizeof url);
	
	HTTPRequest request = new HTTPRequest(url);
    request.Post(obj, onBanRespReceived, sourceId); 

	delete obj;

	return true;
}


void onBanRespReceived(HTTPResponse response, any clientId)
{
	if(response.Status != HTTPStatus_OK)
	{
		if(response.Status == HTTPStatus_Conflict)
		{
			ReplyToCommand(clientId, "Duplicate ban");
			return ;
		}
		ReplyToCommand(clientId, "Unhandled error response");
		return ;
	}


	JSONObject data = view_as<JSONObject>(response.Data); 

	int banId = data.GetInt("ban_id");
	ReplyToCommand(clientId, "User banned (#%d)", banId);
}
