#include "TDM_Structs.as";

/*
void onTick( CRules@ this )
{
    //see the logic script for this
}
*/

void onInit(CRules@ this)
{
	CBitStream stream;
	stream.write_u16(0xDEAD);
	this.set_CBitStream("tdm_serialised_team_hud", stream);
}

void onRender(CRules@ this)
{
	if (g_videorecording)
		return;

	CPlayer@ p = getLocalPlayer();

	if (p is null || !p.isMyPlayer()) { return; }

	GUI::SetFont("menu");

	CBitStream serialised_team_hud;
	this.get_CBitStream("tdm_serialised_team_hud", serialised_team_hud);

	if (serialised_team_hud.getBytesUsed() > 10)
	{
		serialised_team_hud.Reset();
		u16 check;

		if (serialised_team_hud.saferead_u16(check) && check == 0x5afe)
		{
			const string gui_image_fname = "Rules/TDM/TDMGui.png";

			while (!serialised_team_hud.isBufferEnd())
			{
				TDM_HUD hud(serialised_team_hud);
				Vec2f topLeft = Vec2f(8, 8 + 64 * hud.team_num);
				GUI::DrawIcon(gui_image_fname, 0, Vec2f(128, 32), topLeft, 1.0f, hud.team_num);
				int team_player_count = 0;
				int team_dead_count = 0;
				int step = 0;
				Vec2f startIcons = Vec2f(64, 8);
				Vec2f startSkulls = Vec2f(160, 8);
				string player_char = "";
				int size = int(hud.unit_pattern.size());

				while (step < size)
				{
					player_char = hud.unit_pattern.substr(step, 1);
					step++;

					if (player_char == " ") { continue; }

					if (player_char != "s")
					{
						bool newClass = false;
						int player_frame = 1;

						if (player_char == "a")
						{
							player_frame = 2;
						}
						else if (player_char == "r")//rockthrower
						{
							player_frame = 0;
							newClass = true;
						}
						else if (player_char == "m")//medic
						{
							player_frame = 1;
							newClass = true;
						}
						else if (player_char == "p")//spearman
						{
							player_frame = 2;
							newClass = true;
						}
						else if (player_char == "i")//assassin
						{
							player_frame = 3;
							newClass = true;
						}
						else if (player_char == "c")//crossbowman
						{
							player_frame = 4;
							newClass = true;
						}
						else if (player_char == "u")//musketman
						{
							player_frame = 5;
							newClass = true;
						}
						else if(player_char == "n")//demolitionist
						{
							player_frame = 6;
							newClass = true;
						}
						else if(player_char == "h")//warhammer
						{
							player_frame = 7;
							newClass = true;
						}
						else if(player_char == "d")//duelist
						{
							player_frame = 8;
							newClass = true;
						}
						else if(player_char == "w")//weaponthrower
						{
							player_frame = 9;
							newClass = true;
						}
						else if(player_char == "f")//firelancer
						{
							player_frame = 10;
							newClass = true;
						}
						else if(player_char == "g")//gunner
						{
							player_frame = 11;
							newClass = true;
						}
						else if(player_char == "b")//butcher
						{
							player_frame = 12;
							newClass = true;
						}

						if (!newClass) GUI::DrawIcon(gui_image_fname, 12 + player_frame, Vec2f(16, 16), topLeft + startIcons + Vec2f(team_player_count * 8, 0) , 1.0f, hud.team_num);
						else GUI::DrawIcon("LWBTDMGui", player_frame, Vec2f(16, 16), topLeft + startIcons + Vec2f(team_player_count * 8, 0) , 1.0f, hud.team_num);
						team_player_count++;
					}
					else
					{
						GUI::DrawIcon(gui_image_fname, 12 , Vec2f(16, 16), topLeft + startSkulls + Vec2f(team_dead_count * 16, 0) , 1.0f, hud.team_num);
						team_dead_count++;
					}
				}

				if (hud.spawn_time != 255)
				{
					string time = "" + hud.spawn_time;
					GUI::DrawText(time, topLeft + Vec2f(196, 42), SColor(255, 255, 255, 255));
				}

				string kills = getTranslatedString("WARMUP");

				if (hud.kills_limit > 0)
				{
					kills = getTranslatedString("KILLS: {CURRENT}/{LIMIT}").replace("{CURRENT}", "" + hud.kills).replace("{LIMIT}", "" + hud.kills_limit);
				}
				else if (hud.kills_limit == -2)
				{
					kills = getTranslatedString("SUDDEN DEATH");
				}

				GUI::DrawText(kills, topLeft + Vec2f(64, 42), SColor(255, 255, 255, 255));
			}
		}

		serialised_team_hud.Reset();
	}

	string propname = "tdm spawn time " + p.getUsername();
	if (p.getBlob() is null && this.exists(propname))
	{
		u8 spawn = this.get_u8(propname);

		if (spawn != 255)
		{
			if (spawn == 254)
			{
				GUI::DrawText(getTranslatedString("In Queue to Respawn...") , Vec2f(getScreenWidth() / 2 - 70, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
			}
			else if (spawn == 253)
			{
				GUI::DrawText(getTranslatedString("No Respawning - Wait for the Game to End.") , Vec2f(getScreenWidth() / 2 - 180, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
			}
			else
			{
				GUI::DrawText(getTranslatedString("Respawning in: {SEC}").replace("{SEC}", "" + spawn), Vec2f(getScreenWidth() / 2 - 70, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
			}
		}
	}
}
