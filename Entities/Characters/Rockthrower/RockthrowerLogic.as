// Builder logic

#include "Hitters.as";
#include "KnockedCommon.as";
#include "BuilderCommon.as";
#include "RockthrowerCommon.as";
#include "ActivationThrowCommon.as"
#include "RunnerCommon.as";
#include "ShieldCommon.as";
#include "Help.as";
#include "Requirements.as"
#include "BuilderHittable.as";
#include "PlacementCommon.as";
#include "ParticleSparks.as";
#include "MaterialCommon.as";
#include "EmotesCommon.as";

const f32 hit_damage = 0.5f;

f32 pickaxe_distance = 10.0f;
u8 delay_between_hit = 12;
u8 delay_between_hit_structure = 10;

void onInit(CBlob@ this)
{
	RockthrowerInfo rockthrower;
	this.set("rockthrowerInfo", @rockthrower);

	// make moba rockthrower throwing rocks
	if (this.getName() == "rockthrower_moba")
	{
		rockthrower.action = Action::throw;
	}

	this.set_f32("gib health", -1.5f);

	this.Tag("player");
	this.Tag("flesh");

	HitData hitdata;
	this.set("hitdata", hitdata);

	PickaxeInfo PI;
	this.set("pi", PI);

	PickaxeInfo SPI; // server
	this.set("spi", SPI);

	this.addCommandID("pickaxe");
	this.addCommandID("throwrock");
	this.addCommandID("throwrock client");
	this.addCommandID("constructboulder");
	this.addCommandID("constructboulder client");

	CShape@ shape = this.getShape();
	shape.SetRotationsAllowed(false);
	shape.getConsts().net_threshold_multiplier = 0.5f;

	this.set_Vec2f("inventory offset", Vec2f(0.0f, 160.0f));

	AddIconToken("$Help_Hammer$", "LWBHelpIcons.png", Vec2f(16, 16), 1);
	AddIconToken("$Help_Action1$", "LWBHelpIcons.png", Vec2f(8, 16), 4);
	AddIconToken("$Help_Action2$", "LWBHelpIcons.png", Vec2f(8, 16), 5);
	SetHelp(this, "help self action2", "rockthrower", getTranslatedString("$Help_Hammer$Dig/Chop  $KEY_HOLD$$RMB$"), "", 255);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 0, Vec2f(16, 16));
	}
}

void onTick(CBlob@ this)
{
	if (this.isInInventory())
		return;

	const bool ismyplayer = this.isMyPlayer();

	if (ismyplayer && getHUD().hasMenus())
	{
		return;
	}

	RockthrowerInfo@ rockthrower;
	if (!this.get("rockthrowerInfo", @rockthrower))
	{
		return;
	}

	// description
	/*
	if (u_showtutorial && ismyplayer && !this.hasTag("spoke description"))
	{
		this.maxChatBubbleLines = 255;
		this.Chat("Throw many rocks for area control!\n\n[LMB] to action(select in inventory)\n[RMB] to mine\n[SPACE] to make boulder when select throwing\nAlso can use the drill");
		this.set_u8("emote", Emotes::off);
		this.set_u32("emotetime", getGameTime() + 300);
		this.Tag("spoke description");
	}
	*/

	if (ismyplayer && this.isKeyPressed(key_action1) && !this.isKeyPressed(key_inventory)) //Don't let the builder place blocks if he/she is selecting which one to place
	{
		BlockCursor @bc;
		this.get("blockCursor", @bc);

		HitData@ hitdata;
		this.get("hitdata", @hitdata);
		hitdata.blobID = 0;
		hitdata.tilepos = bc.buildable ? bc.tileAimPos : Vec2f(-8, -8);
	}

	// get rid of the built item
	if (this.isKeyJustPressed(key_inventory) || this.isKeyJustPressed(key_pickup))
	{
		this.set_u8("buildblob", 255);

		CBlob@ blob = this.getCarriedBlob();
		if (blob !is null && blob.hasTag("temp blob"))
		{
			blob.Untag("temp blob");
			blob.server_Die();
		}
	}

	bool hasDrill = false;
	CBlob@ maybeDrill = this.getCarriedBlob();
	if(maybeDrill !is null && maybeDrill.getName() == "drill") hasDrill = true;

	Throw(this, rockthrower, hasDrill); // need to operate on all side because of slow system

	bool responsible = ismyplayer;
	if (isServer() && !ismyplayer)
	{
		CPlayer@ p = this.getPlayer();
		if (p !is null)
		{
			responsible = p.isBot();
		}
		else // like moba mobs
		{
			responsible = true;
		}
	}

	// activate/throw
	if (responsible)
	{
		Pickaxe(this, rockthrower);
		if (rockthrower.boulderTimer > 0) rockthrower.boulderTimer--;

		if(this.getCarriedBlob() is null && rockthrower.action == Action::ladder && this.isKeyJustPressed(key_action1))// reload ladder
			this.SendCommand(this.getCommandID("setladder"));
		else if (this.isKeyJustPressed(key_action3))
		{
			CBlob@ carried = this.getCarriedBlob();
			if(carried is null && isShootTime(this))
			{
				if(rockthrower.boulderTimer == 0 && hasBoulderStones(this))
				{
					this.SendCommand(this.getCommandID("constructboulder"));
					rockthrower.boulderTimer = 150;
				}
				else
				{
					Sound::Play("/NoAmmo");
				}
			}
			else if (carried is null || !(carried.hasTag("temp blob")))
			{
				client_SendThrowOrActivateCommand(this);
			}
		}
	}

	// slow down walking
	bool slow = this.isKeyPressed(key_action2) || (isShootTime(this) && rockthrower.throwTimer > 0 && !hasDrill);
	if (slow)
	{
		RunnerMoveVars@ moveVars;
		if (this.get("moveVars", @moveVars))
		{
			moveVars.walkFactor = 0.5f;
			moveVars.jumpFactor = 0.5f;
		}
		this.Tag("prevent crouch");
	}

	QueuedHit@ queued_hit;
	if (this.get("queued pickaxe", @queued_hit))
	{
		if (queued_hit !is null && getGameTime() >= queued_hit.scheduled_tick)
		{
			HandlePickaxeCommand(this, queued_hit.params);
			this.set("queued pickaxe", null);
		}
	}
}

//helper class to reduce function definition cancer
//and allow passing primitives &inout
class SortHitsParams
{
	Vec2f aimPos;
	Vec2f tilepos;
	Vec2f pos;
	bool justCheck;
	bool extra;
	bool hasHit;
	HitInfo@ bestinfo;
	f32 bestDistance;
};

void Throw(CBlob@ this, RockthrowerInfo@ rockthrower, bool hasDrill)
{
	PickaxeInfo@ PI;
	if (!this.get("pi", @PI)) return;

	if (rockthrower.throwTimer >= 15)
	{
		rockthrower.throwTimer = 0;
	}

	bool just_pressed = false;
	if (isShootTime(this) && !this.isKeyPressed(key_action2) && this.isKeyPressed(key_action1) && PI.pickaxe_timer >= 0 && rockthrower.throwTimer == 0)
	{
		just_pressed = true;
		rockthrower.throwTimer++;
	}

	if (rockthrower.throwTimer == 0) return;

	if (rockthrower.throwTimer > 0 && !just_pressed)
	{
		rockthrower.throwTimer++;
	}

	bool ismyplayer = this.isMyPlayer();
	bool responsible = ismyplayer;
	if (isServer() && !ismyplayer)
	{
		CPlayer@ p = this.getPlayer();
		if (p !is null)
		{
			responsible = p.isBot();
		}
		else // like moba mobs
		{
			responsible = true;
		}
	}

	bool justCheck = rockthrower.throwTimer == 7;
	if (justCheck && responsible && !hasDrill)
	{
		if (hasStones(this))
		{
			this.SendCommand(this.getCommandID("throwrock"));
		}
		else
		{
			Sound::Play("/NoAmmo");
		}
	}
}

//helper class to reduce function definition cancer
//and allow passing primitives &inout
class PickaxeInfo
{
	u32 pickaxe_timer;
	u32 last_pickaxed;
	bool last_hit_structure;
};

void Pickaxe(CBlob@ this, RockthrowerInfo@ rockthrower)
{
	HitData@ hitdata;
	this.get("hitdata", @hitdata);

	PickaxeInfo@ PI;
	if (!this.get("pi", @PI)) return;

	// magic number :D
	if (getGameTime() - PI.last_pickaxed >= 12 && isClient())
	{
		this.get("hitdata", @hitdata);
		hitdata.blobID = 0;
		hitdata.tilepos = Vec2f_zero;
	}

	u8 delay = delay_between_hit;
	if (PI.last_hit_structure) delay = delay_between_hit_structure;

	if (PI.pickaxe_timer >= delay)
	{
		PI.pickaxe_timer = 0;
	}

	bool just_pressed = false;
	if (rockthrower.throwTimer <= 0 && this.isKeyPressed(key_action2) && PI.pickaxe_timer == 0)
	{
		just_pressed = true;
		PI.pickaxe_timer++;
	}

	if (PI.pickaxe_timer == 0) return;

	if (PI.pickaxe_timer > 0 && !just_pressed)
	{
		PI.pickaxe_timer++;
	}

	bool justCheck = PI.pickaxe_timer == 5;
	if (!justCheck) return;

	// we can only hit blocks with pickaxe on 5th tick of hitting, every 10/12 ticks

	this.get("hitdata", @hitdata);

	if (hitdata is null) return;

	Vec2f blobPos = this.getPosition();
	Vec2f aimPos = this.getAimPos();
	Vec2f aimDir = aimPos - blobPos;

	// get tile surface for aiming at little static blobs
	Vec2f normal = aimDir;
	normal.Normalize();

	Vec2f attackVel = normal;

	hitdata.blobID = 0;
	hitdata.tilepos = Vec2f_zero;

	f32 arcdegrees = 90.0f;

	f32 aimangle = aimDir.Angle();
	Vec2f pos = blobPos - Vec2f(2, 0).RotateBy(-aimangle);
	f32 attack_distance = this.getRadius() + pickaxe_distance;
	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;

	bool hasHit = false;

	const f32 tile_attack_distance = attack_distance * 1.5f;
	Vec2f tilepos = blobPos + normal * Maths::Min(aimDir.Length() - 1, tile_attack_distance);
	Vec2f surfacepos;
	map.rayCastSolid(blobPos, tilepos, surfacepos);

	Vec2f surfaceoff = (tilepos - surfacepos);
	f32 surfacedist = surfaceoff.Normalize();
	tilepos = (surfacepos + (surfaceoff * (map.tilesize * 0.5f)));

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@ bestinfo = null;
	f32 bestDistance = 100000.0f;

	HitInfo@[] hitInfos;

	//setup params for ferrying data in/out
	SortHitsParams@ hit_p = SortHitsParams();

	//copy in
	hit_p.aimPos = aimPos;
	hit_p.tilepos = tilepos;
	hit_p.pos = pos;
	hit_p.justCheck = justCheck;
	hit_p.extra = true;
	hit_p.hasHit = hasHit;
	@(hit_p.bestinfo) = bestinfo;
	hit_p.bestDistance = bestDistance;

	if (map.getHitInfosFromArc(pos, -aimangle, arcdegrees, attack_distance, this, @hitInfos))
	{
		SortHits(this, hitInfos, hit_damage, hit_p);
	}

	aimPos = hit_p.aimPos;
	tilepos = hit_p.tilepos;
	pos = hit_p.pos;
	justCheck = hit_p.justCheck;
	hasHit = hit_p.hasHit;
	@bestinfo = hit_p.bestinfo;
	bestDistance = hit_p.bestDistance;

	Tile tile = map.getTile(tilepos);
	bool noBuildZone = inNoBuildZone(map, tilepos, tile.type);
	bool isgrass = false;

	if ((tilepos - aimPos).Length() < bestDistance - 4.0f && map.getBlobAtPosition(tilepos) is null)
	{
		Tile tile = map.getTile(surfacepos);

		if (!noBuildZone && !map.isTileGroundBack(tile.type))
		{
			//normal, honest to god tile
			if (map.isTileBackgroundNonEmpty(tile) || map.isTileSolid(tile))
			{
				hasHit = true;
				hitdata.tilepos = tilepos;
			}
			else if (map.isTileGrass(tile.type))
			{
				//NOT hashit - check last for grass
				isgrass = true;
			}
		}
	}

	if (!hasHit)
	{
		//copy in
		hit_p.aimPos = aimPos;
		hit_p.tilepos = tilepos;
		hit_p.pos = pos;
		hit_p.justCheck = justCheck;
		hit_p.extra = false;
		hit_p.hasHit = hasHit;
		@(hit_p.bestinfo) = bestinfo;
		hit_p.bestDistance = bestDistance;

		//try to find another possible one
		if (bestinfo is null)
		{
			SortHits(this, hitInfos, hit_damage, hit_p);
		}

		//copy out
		aimPos = hit_p.aimPos;
		tilepos = hit_p.tilepos;
		pos = hit_p.pos;
		justCheck = hit_p.justCheck;
		hasHit = hit_p.hasHit;
		@bestinfo = hit_p.bestinfo;
		bestDistance = hit_p.bestDistance;

		//did we find one (or have one from before?)
		if (bestinfo !is null)
		{
			hitdata.blobID = bestinfo.blob.getNetworkID();
		}
	}

	if (isgrass && bestinfo is null)
	{
		hitdata.tilepos = tilepos;
	}

	bool hitting_structure = false; // hitting player-built blocks -> smaller delay

	if (hitdata.blobID == 0)
	{
		CBitStream params;
		params.write_u16(0);
		params.write_Vec2f(hitdata.tilepos);
		this.SendCommand(this.getCommandID("pickaxe"), params);

		TileType t = getMap().getTile(hitdata.tilepos).type;
		if (t != CMap::tile_empty && t != CMap::tile_ground_back)
		{
			uint16 type = map.getTile(hitdata.tilepos).type;
			if (!inNoBuildZone(map, hitdata.tilepos, type))
			{
				// for smaller delay
				if (map.isTileWood(type) || // wood tile
					(type >= CMap::tile_wood_back && type <= 207) || // wood backwall
					map.isTileCastle(type) || // castle block
					(type >= CMap::tile_castle_back && type <= 79) || // castle backwall
					 type == CMap::tile_castle_back_moss) // castle mossbackwall
				{
					hitting_structure = true;
				}
			}

			if (map.isTileBedrock(type))
			{
				this.getSprite().PlaySound("/metal_stone.ogg");
				sparks(tilepos, attackVel.Angle(), 1.0f);
			}
		}
	}
	else
	{
		CBlob@ b = getBlobByNetworkID(hitdata.blobID);
		if (b !is null)
		{
			CBitStream params;
			params.write_u16(hitdata.blobID);
			params.write_Vec2f(hitdata.tilepos);
			this.SendCommand(this.getCommandID("pickaxe"), params);

			// for smaller delay
			string attacked_name = b.getName();
			if (attacked_name == "bridge" ||
				attacked_name == "wooden_platform" ||
				b.hasTag("door") ||
				attacked_name == "ladder" ||
				attacked_name == "spikes" ||
				b.hasTag("builder fast hittable")
				)
			{
				hitting_structure = true;
			}
		}
	}

	PI.last_hit_structure = hitting_structure;
	PI.last_pickaxed = getGameTime();
}

void SortHits(CBlob@ this, HitInfo@[]@ hitInfos, f32 damage, SortHitsParams@ p)
{
	//HitInfo objects are sorted, first come closest hits
	for (uint i = 0; i < hitInfos.length; i++)
	{
		HitInfo@ hi = hitInfos[i];

		CBlob@ b = hi.blob;
		if (b !is null) // blob
		{
			if (!canHit(this, b, p.tilepos, p.extra))
			{
				continue;
			}

			if (!p.justCheck && isUrgent(this, b))
			{
				p.hasHit = true;			
			}
			else
			{
				bool never_ambig = neverHitAmbiguous(b);
				f32 len = never_ambig ? 1000.0f : (p.aimPos - b.getPosition()).Length();
				if (len < p.bestDistance)
				{
					if (!never_ambig)
						p.bestDistance = len;

					@(p.bestinfo) = hi;
				}
			}
		}
	}
}

bool ExtraQualifiers(CBlob@ this, CBlob@ b, Vec2f tpos)
{
	//urgent stuff gets a pass here
	if (isUrgent(this, b))
		return true;

	//check facing - can't hit stuff we're facing away from
	f32 dx = (this.getPosition().x - b.getPosition().x) * (this.isFacingLeft() ? 1 : -1);
	if (dx < 0)
		return false;

	//only hit static blobs if aiming directly at them
	CShape@ bshape = b.getShape();
	if (bshape.isStatic())
	{
		bool bigenough = bshape.getWidth() >= 8 &&
		                 bshape.getHeight() >= 8;

		if (bigenough)
		{
			if (!b.isPointInside(this.getAimPos()) && !b.isPointInside(tpos))
			{
				return false;
			}
		}
		else
		{
			Vec2f bpos = b.getPosition();
			//get centered on the tile it's positioned on (for offset blobs like spikes)
			Vec2f tileCenterPos = Vec2f(s32(bpos.x / 8), s32(bpos.y / 8)) * 8 + Vec2f(4, 4);
			f32 dist = Maths::Min((tileCenterPos - this.getAimPos()).LengthSquared(),
			                      (tileCenterPos - tpos).LengthSquared());
			if (dist > 25) //>5*5
				return false;
		}
	}

	return true;
}

bool neverHitAmbiguous(CBlob@ b)
{
	string name = b.getName();
	return name == "saw";
}

bool canHit(CBlob@ this, CBlob@ b, Vec2f tpos, bool extra = true)
{
	if (this is b) return false;

	if (extra && !ExtraQualifiers(this, b, tpos))
	{
		return false;
	}

	if (b.hasTag("invincible"))
	{
		return false;
	}

	if (b.getTeamNum() == this.getTeamNum())
	{
		//no hitting friendly carried stuff
		if (b.isAttached())
			return false;

		if (BuilderAlwaysHit(b) || b.hasTag("dead") || b.hasTag("vehicle"))
			return true;

		if (b.getName() == "saw" || b.getName() == "trampoline" || b.getName() == "crate")
			return true;

		return false;

	}
	else if (b.getName() == "statue")//enemy statues, it's not my team bacause of over. can I make statue can be hit by genuine builder?
	{
		return true;
	}
	//no hitting stuff in hands
	else if (b.isAttached() && !b.hasTag("player"))
	{
		return false;
	}

	//static/background stuff
	CShape@ b_shape = b.getShape();
	if (!b.isCollidable() || (b_shape !is null && b_shape.isStatic()))
	{
		//maybe we shouldn't hit this..
		//check if we should always hit
		if (BuilderAlwaysHit(b))
		{
			if (!b.isCollidable() && !isUrgent(this, b))
			{
				//TODO: use a better overlap check here
				//this causes issues with quarters and
				//any other case where you "stop overlapping"
				if (!this.isOverlapping(b))
					return false;
			}
			return true;
		}
		//otherwise no hit
		return false;
	}

	return true;
}

class QueuedHit
{
	CBitStream params;
	int scheduled_tick;
}

void HandlePickaxeCommand(CBlob@ this, CBitStream@ params)
{
	PickaxeInfo@ SPI;
	if (!this.get("spi", @SPI)) return;

	u16 blobID;
	Vec2f tilepos;

	if (!params.saferead_u16(blobID)) return;
	if (!params.saferead_Vec2f(tilepos)) return;

	Vec2f blobPos = this.getPosition();
	Vec2f aimPos = this.getAimPos();
	Vec2f attackVel = aimPos - blobPos;

	attackVel.Normalize();

	bool hitting_structure = false;

	if (blobID == 0)
	{
		CMap@ map = getMap();
		TileType t = map.getTile(tilepos).type;
		if (t != CMap::tile_empty && t != CMap::tile_ground_back)
		{
			// 5 blocks range check
			Vec2f tsp = map.getTileSpacePosition(tilepos);
			Vec2f wsp = map.getTileWorldPosition(tsp);
			wsp += Vec2f(4, 4); // get center of block
			f32 distance = Vec2f(blobPos - wsp).Length();
			if (distance > 40.0f) return;

			uint16 type = map.getTile(tilepos).type;
			if (!inNoBuildZone(map, tilepos, type))
			{
				map.server_DestroyTile(tilepos, 1.0f, this);
				Material::fromTile(this, type, 1.0f);
			}

			// for smaller delay
			if (map.isTileWood(type) || // wood tile
				(type >= CMap::tile_wood_back && type <= 207) || // wood backwall
				map.isTileCastle(type) || // castle block
				(type >= CMap::tile_castle_back && type <= 79) || // castle backwall
					type == CMap::tile_castle_back_moss) // castle mossbackwall
			{
				hitting_structure = true;
			}
		}
	}
	else
	{
		CBlob@ b = getBlobByNetworkID(blobID);
		if (b !is null)
		{
			// 4 blocks range check
			f32 distance = this.getDistanceTo(b);
			if (distance > 32.0f) return;

			bool isdead = b.hasTag("dead");

			f32 attack_power = hit_damage;

			if (isdead) //double damage to corpses
			{
				attack_power *= 2.0f;
			}

			const bool teamHurt = !b.hasTag("flesh") || isdead;

			if (isServer())
			{
				this.server_Hit(b, tilepos, attackVel, attack_power, Hitters::hammer, teamHurt);
				Material::fromBlob(this, b, attack_power);
			}

			// for smaller delay
			string attacked_name = b.getName();
			if (attacked_name == "bridge" ||
				attacked_name == "wooden_platform" ||
				b.hasTag("door") ||
				attacked_name == "ladder" ||
				attacked_name == "spikes" ||
				b.hasTag("builder fast hittable")
				)
			{
				hitting_structure = true;
			}
		}
	}

	SPI.last_hit_structure = hitting_structure;
	SPI.last_pickaxed = getGameTime();
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("pickaxe") && isServer())
	{
		PickaxeInfo@ SPI;
		if (!this.get("spi", @SPI)) return;

		u8 delay = delay_between_hit;
		if (SPI.last_hit_structure) delay = delay_between_hit_structure;

		QueuedHit@ queued_hit;
		if (this.get("queued pickaxe", @queued_hit))
		{
			if (queued_hit !is null)
			{
				// cancel queued hit.
				return;
			}
		}

		// allow for one queued hit in-flight; reject any incoming one in the
		// mean time (would only happen with massive lag in legit scenarios)
		if (getGameTime() - SPI.last_pickaxed < delay)
		{
			QueuedHit queued_hit;
			queued_hit.params = params;
			queued_hit.scheduled_tick = SPI.last_pickaxed + delay;
			this.set("queued pickaxe", @queued_hit);
			return;
		}

		HandlePickaxeCommand(this, @params);
	}
	else if (cmd == this.getCommandID("throwrock") && isServer())
	{
		Vec2f offset(this.isFacingLeft() ? 2 : -2, -2);
		Vec2f rockPos = this.getPosition() + offset;
		Vec2f rockVel = this.getAimPos() - rockPos;

		if (!hasStones(this))
			return;
		CBlob@ rock = server_CreateBlobNoInit("throwingrock");
		if (rock !is null)
		{
			rock.SetDamageOwnerPlayer(this.getPlayer());
			rock.Init();
		
			rock.IgnoreCollisionWhileOverlapped(this);
			rock.server_setTeamNum(this.getTeamNum());
			rock.setPosition(rockPos);
			rockVel.Normalize();
			rockVel *= 12.0f;
			rock.setVelocity(rockVel);
			this.TakeBlob("mat_stone", 1);

			this.SendCommand(this.getCommandID("throwrock client"));
		}
	}
	else if (cmd == this.getCommandID("throwrock client") && isClient())
	{
		this.getSprite().PlaySound("/ArgLong");
	}
	else if (cmd == this.getCommandID("constructboulder") && isServer())
	{
		if (!hasBoulderStones(this))
			return;
		CBlob@ boulder = server_CreateBlob("boulder", this.getTeamNum(), this.getPosition());
		if (boulder !is null)
		{
			this.server_Pickup(boulder);
			this.TakeBlob("mat_stone", 35);

			this.SendCommand(this.getCommandID("constructboulder client"));
		}
	}
	else if (cmd == this.getCommandID("constructboulder client") && isClient())
	{
		this.getSprite().PlaySound("/ConstructShort");
	}
}

// stun shielded knight
void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (customData == Hitters::hammer)
	{
		if (blockAttack(hitBlob, velocity, 0.0f) && isKnockable(hitBlob))
		{
			this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(hitBlob, 10, true);
		}
	}
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	// ignore collision for built blob
	BuildBlock[][]@ blocks;
	if (!this.get("blocks", @blocks))
	{
		return;
	}
	for (u8 i = 0; i < blocks[0].length; i++)
	{
		BuildBlock@ block = blocks[0][i];
		if (block !is null && block.name == detached.getName())
		{
			this.IgnoreCollisionWhileOverlapped(null);
			detached.IgnoreCollisionWhileOverlapped(null);
		}
	}

	// BUILD BLOB
	// take requirements from blob that is built and play sound
	// put out another one of the same
	if (detached.hasTag("temp blob"))
	{
		detached.Untag("temp blob");
		
		if (!detached.hasTag("temp blob placed"))
		{
			detached.server_Die();
			return;
		}
		
		uint i = this.get_u8("buildblob");
		if (i >= 0 && i < blocks[0].length)
		{
			BuildBlock@ b = blocks[0][i];
			if (b.name == detached.getName())
			{
				this.set_u8("buildblob", 255);

				CInventory@ inv = this.getInventory();

				CBitStream missing;
				if (hasRequirements(inv, b.reqs, missing, not b.buildOnGround))
				{
					server_TakeRequirements(inv, b.reqs);
				}
				// take out another one if in inventory
				server_BuildBlob(this, blocks[0], i);
			}
		}
	}
	else if (detached.getName() == "seed")
	{
		if (not detached.hasTag('temp blob placed')) return;

		CBlob@ anotherBlob = this.getInventory().getItem(detached.getName());
		if (anotherBlob !is null)
		{
			this.server_Pickup(anotherBlob);
		}
	}
}

void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	// destroy built blob if somehow they got into inventory
	if (blob.hasTag("temp blob"))
	{
		blob.server_Die();
		blob.Untag("temp blob");
	}

	if (this.isMyPlayer() && blob.hasTag("material"))
	{
		SetHelp(this, "help inventory", "rockthrower", "$Help_Action1$$Swap$$Help_Action2$           $KEY_TAP$$KEY_F$", "", 255);
	}
}
