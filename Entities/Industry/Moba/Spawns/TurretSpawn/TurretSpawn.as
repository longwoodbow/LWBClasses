// Knight Workshop

#include "Requirements.as"
#include "ShopCommon.as";
#include "Descriptions.as";
#include "WARCosts.as";
#include "CheckSpam.as";
#include "ProductionCommon.as";



void onInit(CBlob@ this)
{
	this.set_TileType("background tile", CMap::tile_wood_back);
	this.Tag("getthis");
	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;
	this.set_u32("minionCD", 0);
	addSeedItem( this, "blah", "bleg", 23, 1);
}
CBlob@ SpawnMook(Vec2f pos, const string &in classname, u8 team)
	{
		CBlob@ blob = server_CreateBlobNoInit(classname);
		if (blob !is null)
		{
			//setup ready for init
			blob.setSexNum(XORRandom(2));
			blob.server_setTeamNum(team);
			blob.setPosition(pos + Vec2f(4.0f, 0.0f));
			blob.set_s32("difficulty", 10);
			SetMookHead(blob, classname);
			blob.Init();
			if(blob.getTeamNum() == 1)
				blob.SetFacingLeft(true);
			blob.getBrain().server_SetActive(true);
			blob.server_SetTimeToDie(60 * 3);	 // delete after 6 minutes
		}
		return blob;
	}
	void GiveAmmo(CBlob@ blob)
	{
		if (blob.getName() == "archer")
		{
			CBlob@ mat = server_CreateBlob("mat_arrows");
			if (mat !is null)
			{
				blob.server_PutInInventory(mat);
			}
		}
	}

	void SetMookHead(CBlob@ blob, const string &in classname)
	{
		const bool isKnight = classname == "knight";

		int head = 15;
		int selection = 10 + XORRandom(3);
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
	ShopItem@ addSeedItem( CBlob@ this, const string &in seedName,const string &in  description, u16 timeToMakeSecs, const u16 quantityLimit, CBitStream@ requirements = null )
{
	const string newIcon = "$" + seedName + "$";
	ShopItem@ item = addProductionItem( this, "archerTurret", newIcon, "archerTurret", "", 24, false, 2, requirements );
	return item;
}



void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shop made item client") && isClient())
	{
		this.getSprite().PlaySound("/ChaChing.ogg");
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