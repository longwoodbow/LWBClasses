// Knight Workshop

#include "Requirements.as"
#include "ShopCommon.as";
#include "Descriptions.as";
#include "WARCosts.as";
#include "CheckSpam.as";
#include "GenericButtonCommon.as";
#include "RockthrowerCommon.as";



void onInit(CBlob@ this)
{
	this.set_TileType("background tile", CMap::tile_wood_back);
	this.Tag("getthis");
	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;
	this.set_u32("minionCD", 0);
	this.Tag("invincable");
	this.set_u8("def", 0);
	this.set_u8("atk", 0);
	this.set_u8("spd", 0);
	this.set_u8("jmp", 0);
	this.addCommandID("upgrade");
	this.addCommandID("upgrade client");
	AddIconToken("$upgrade_spawn$", "InteractionIcons.png", Vec2f(32, 32), 20);
}
CBlob@ SpawnMook(CBlob@ this, Vec2f pos, const string &in classname, u8 team)
	{
		CBlob@ blob = server_CreateBlobNoInit(classname);
		if (blob !is null)
		{
			//setup ready for init
			blob.setSexNum(XORRandom(2));
			blob.server_setTeamNum(team);
			blob.setPosition(pos + Vec2f(4.0f, 0.0f));
			blob.set_s32("difficulty", 15);
			SetMookHead(blob, classname);
			blob.Init();
			if(blob.getTeamNum() == 1)
				blob.SetFacingLeft(true);
			else
				blob.SetFacingLeft(false);
			blob.getBrain().server_SetActive(true);
			blob.server_SetTimeToDie(60 * 1);	 // delete after 6 minutes
			GiveAmmo(blob);

			// upgrades
			blob.set_u8("def", this.get_u8("def"));
			blob.set_u8("atk", this.get_u8("atk"));
			blob.set_u8("spd", this.get_u8("spd"));
			blob.set_u8("jmp", this.get_u8("jmp"));
		}
		return blob;
	}
	void GiveAmmo(CBlob@ blob)
	{
		if (blob.getName() == "rockthrower_moba")
		{
			CBlob@ mat = server_CreateBlob("mat_stone");
			if (mat !is null)
			{
				blob.server_PutInInventory(mat);
			}
		}
		else if (blob.getName() == "butcher_moba")
		{
			CBlob@ mat = server_CreateBlob("mat_poisonmeats");
			if (mat !is null)
			{
				blob.server_PutInInventory(mat);
			}
		}
		else if (blob.getName() == "medic_moba")
		{
			CBlob@ mat = server_CreateBlob("mat_medkits");
			if (mat !is null)
			{
				blob.server_PutInInventory(mat);
			}
		}
	}

	void SetMookHead(CBlob@ blob, const string &in classname)
	{
		const bool isKnight = false;

		int head = 15;
		int selection = 0 + XORRandom(16);
		if (selection > 15)
		{
			selection = 15;
			head = 17 + XORRandom(36);
		}
		else
		{
			if (isKnight)
			{
				switch (selection)
				{
					case 0:  head = 37; break;
					case 1:  head = 18; break;
					case 2:  head = 19; break;
					case 3:  head = 42; break;
					case 4:  head = 22; break;
					case 5:  head = 23; break;
					case 6:  head = 16; break;
					case 7:  head = 48; break;
					case 8:  head = 46; break;
					case 9:  head = 45; break;
					case 10: head = 47; break;
					case 11: head = 20; break;
					case 12: head = 21; break;
					case 13: head = 44; break;
					case 14: head = 43; break;
					case 15: head = 36; break;
				}
			}
			else
			{
				switch (selection)
				{
					case 0:  head = 35; break;
					case 1:  head = 51; break;
					case 2:  head = 52; break;
					case 3:  head = 26; break;
					case 4:  head = 22; break;
					case 5:  head = 27; break;
					case 6:  head = 24; break;
					case 7:  head = 49; break;
					case 8:  head = 17; break;
					case 9:  head = 17; break;
					case 10: head = 17; break;
					case 11: head = 33; break;
					case 12: head = 32; break;
					case 13: head = 34; break;
					case 14: head = 25; break;
					case 15: head = 36; break;
				}
			}
		}

		head += 16; //reserved heads changed

		blob.setHeadNum(head);
	}
void onTick(CBlob@ this)
{
	if (!isServer()) return;
	
		if( this.getTeamNum() < 3 && this.get_u32("minionCD") > 800)
		{
			Vec2f pos = this.getPosition();
			SpawnMook(this, pos, "medic_moba", this.getTeamNum());
			SpawnMook(this, pos + Vec2f(10.0f, 0.0f), "rockthrower_moba", this.getTeamNum());
			SpawnMook(this, pos + Vec2f(-10.0f, 0.0f), "butcher_moba", this.getTeamNum());
			this.set_u32("minionCD", 0);
		}
		else 
			this.set_u32("minionCD", this.get_u32("minionCD") + 1 );
}
/*
void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	if (this.get_u8("atk") < 5)
	{
		CBitStream params;
		params.write_u8(0);
		params.write_u8(this.get_u8("atk") + 1);
		params.write_netid(caller.getNetworkID());
		CButton@ button = caller.CreateGenericButton(
		"$upgrade_spawn$",                             // icon token
		Vec2f(-8.0f, 0.0f),                            // button offset
		this,                                       // button attachment
		this.getCommandID("upgrade"),              // command id
		"Upgrade attack with " + ((this.get_u8("atk") + 1) * 300) + " wood",
		params);               // description
	}

	if (this.get_u8("def") < 5)
	{
		CBitStream params;
		params.write_u8(1);
		params.write_u8(this.get_u8("def") + 1);
		params.write_netid(caller.getNetworkID());
		CButton@ button = caller.CreateGenericButton(
		"$upgrade_spawn$",                             // icon token
		Vec2f(0.0f, 0.0f),                            // button offset
		this,                                       // button attachment
		this.getCommandID("upgrade"),              // command id
		"Upgrade defence with " + ((this.get_u8("def") + 1) * 300) + " wood",
		params);               // description
	}

	if (this.get_u8("spd") < 5)
	{
		CBitStream params;
		params.write_u8(2);
		params.write_u8(this.get_u8("spd") + 1);
		params.write_netid(caller.getNetworkID());
		CButton@ button = caller.CreateGenericButton(
		"$upgrade_spawn$",                             // icon token
		Vec2f(8.0f, 0.0f),                            // button offset
		this,                                       // button attachment
		this.getCommandID("upgrade"),              // command id
		"Upgrade speed with " + ((this.get_u8("spd") + 1) * 300) + " wood",
		params);               // description
	}
}
*/
void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("upgrade") && isServer())
	{
		u8 type;
		if (!params.saferead_u8(type)) return;
		u8 level;
		if (!params.saferead_u8(level)) return;
		u16 callerID;
		if (!params.saferead_netid(callerID)) return;
		CBlob@ caller = getBlobByNetworkID(callerID);
		if (caller is null) return;

		bool success = false;

		switch (type)
		{
			case 0:
			if (this.get_u8("atk") + 1 == level && caller.getBlobCount("mat_wood") >= level * 300)
			{
				this.set_u8("atk", level);
				caller.TakeBlob("mat_wood", level * 300);
				success = true;
			}
			break;

			case 1:
			if (this.get_u8("def") + 1 == level && caller.getBlobCount("mat_wood") >= level * 300)
			{
				this.set_u8("def", level);
				caller.TakeBlob("mat_wood", level * 300);
				success = true;
			}
			break;

			case 2:
			if (this.get_u8("spd") + 1 == level && caller.getBlobCount("mat_wood") >= level * 300)
			{
				this.set_u8("spd", level);
				this.set_u8("jmp", level);
				caller.TakeBlob("mat_wood", level * 300);
				success = true;
			}
			break;
		}

		if (!success) type = 3;

		CBitStream newParams;
		newParams.write_u8(type);
		newParams.write_u8(level);
		this.SendCommand(this.getCommandID("upgrade client"), newParams);
	}
	else if (cmd == this.getCommandID("upgrade client") && isClient())
	{
		u8 type;
		if (!params.saferead_u8(type)) return;
		u8 level;
		if (!params.saferead_u8(level)) return;

		switch (type)
		{
			case 0:
			this.set_u8("atk", level);
			break;

			case 1:
			this.set_u8("def", level);
			break;

			case 2:
			this.set_u8("spd", level);
			this.set_u8("jmp", level);
			break;
		}

		if (type != 3) this.getSprite().PlaySound("/ChaChing.ogg");
		else  this.getSprite().PlaySound("/NoAmmo.ogg");
	}
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
	CSprite@ sprite = this.getSprite();
	if (sprite !is null)
	{
		Animation@ destruction = sprite.getAnimation("destruction");
		if (destruction !is null)
		{
			f32 frame = Maths::Floor((this.getInitialHealth() - this.getHealth()) / (this.getInitialHealth() / sprite.animation.getFramesCount()));
			sprite.animation.frame = frame;
		}
	}
}