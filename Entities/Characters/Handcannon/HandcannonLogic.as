// Handcannon logic

#include "BuilderCommon.as";
#include "HandcannonCommon.as"
#include "ActivationThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "Help.as";
#include "Requirements.as"
#include "PlacementCommon.as";
#include "EmotesCommon.as";
#include "RedBarrierCommon.as";
#include "StandardControlsCommon.as";

void onInit(CBlob@ this)
{
	HandcannonInfo handcannon;
	this.set("handcannonInfo", @handcannon);

	this.set_bool("has_ball", false);
	this.set_f32("gib health", -1.5f);
	this.Tag("player");
	this.Tag("flesh");
	//centered on balls
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().SetEmitSound("/Sparkle.ogg");
	this.addCommandID("play fire sound");
	this.addCommandID("sync ignite");
	this.addCommandID("sync ignite client");
	this.addCommandID("request shoot");
	this.addCommandID("axe attack");
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	//AddIconToken("$Shovel$", "LWBHelpIcons.png", Vec2f(16, 16), 12);
	//AddIconToken("$Help_Ball$", "LWBHelpIcons.png", Vec2f(8, 16), 23);

	this.addCommandID(grapple_sync_cmd);

	SetHelp(this, "help self hide", "handcannon", getTranslatedString("Hide    $KEY_S$"), "", 255);
	SetHelp(this, "help self action2", "handcannon", getTranslatedString("$Grapple$ Grappling hook    $RMB$"), "", 255);

	//add a command ID for each ball type

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 16, Vec2f(16, 16));
	}
}

void ManageGrapple(CBlob@ this, HandcannonInfo@ handcannon)
{
	CSprite@ sprite = this.getSprite();
	u8 charge_state = handcannon.charge_state;
	Vec2f pos = this.getPosition();

	const bool right_click = this.isKeyJustPressed(key_action2);

	if (right_click && getBuildMode(this) == HandcannonBuilding::nothing)
	{
		// cancel charging
		if (charge_state != HandcannonParams::not_aiming &&
		    charge_state != HandcannonParams::ignited &&
		    charge_state != HandcannonParams::firing) // allow grapple right after firing
		{
			charge_state = HandcannonParams::not_aiming;
			handcannon.charge_time = 0;
			sprite.SetEmitSoundPaused(true);
			sprite.PlaySound("PopIn.ogg");
		}
		else if (canSend(this) || isServer()) //otherwise grapple
		{
			handcannon.grappling = true;
			handcannon.grapple_id = 0xffff;
			handcannon.grapple_pos = pos;

			handcannon.grapple_ratio = 1.0f; //allow fully extended

			Vec2f direction = this.getAimPos() - pos;

			//aim in direction of cursor
			f32 distance = direction.Normalize();
			if (distance > 1.0f)
			{
				handcannon.grapple_vel = direction * handcannon_grapple_throw_speed;
			}
			else
			{
				handcannon.grapple_vel = Vec2f_zero;
			}

			SyncGrapple(this);
		}

		handcannon.charge_state = charge_state;
	}

	if (handcannon.grappling)
	{
		//update grapple
		//TODO move to its own script?

		if (!this.isKeyPressed(key_action2))
		{
			if (canSend(this) || isServer())
			{
				handcannon.grappling = false;
				SyncGrapple(this);
			}
		}
		else
		{
			const f32 handcannon_grapple_range = handcannon_grapple_length * handcannon.grapple_ratio;
			const f32 handcannon_grapple_force_limit = this.getMass() * handcannon_grapple_accel_limit;

			CMap@ map = this.getMap();

			//reel in
			//TODO: sound
			if (handcannon.grapple_ratio > 0.2f)
				handcannon.grapple_ratio -= 1.0f / getTicksASecond();

			//get the force and offset vectors
			Vec2f force;
			Vec2f offset;
			f32 dist;
			{
				force = handcannon.grapple_pos - this.getPosition();
				dist = force.Normalize();
				f32 offdist = dist - handcannon_grapple_range;
				if (offdist > 0)
				{
					offset = force * Maths::Min(8.0f, offdist * handcannon_grapple_stiffness);
					force *= Maths::Min(handcannon_grapple_force_limit, Maths::Max(0.0f, offdist + handcannon_grapple_slack) * handcannon_grapple_force);
				}
				else
				{
					force.Set(0, 0);
				}
			}

			//left map? too long? close grapple
			if (handcannon.grapple_pos.x < 0 ||
			        handcannon.grapple_pos.x > (map.tilemapwidth)*map.tilesize ||
			        dist > handcannon_grapple_length * 3.0f)
			{
				if (canSend(this) || isServer())
				{
					handcannon.grappling = false;
					SyncGrapple(this);
				}
			}
			else if (handcannon.grapple_id == 0xffff) //not stuck
			{
				const f32 drag = map.isInWater(handcannon.grapple_pos) ? 0.7f : 0.90f;
				const Vec2f gravity(0, 1);

				handcannon.grapple_vel = (handcannon.grapple_vel * drag) + gravity - (force * (2 / this.getMass()));

				Vec2f next = handcannon.grapple_pos + handcannon.grapple_vel;
				next -= offset;

				Vec2f dir = next - handcannon.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while (delta > 0 && !found) //fake raycast
				{
					if (delta > step)
					{
						handcannon.grapple_pos += dir * step;
					}
					else
					{
						handcannon.grapple_pos = next;
					}
					delta -= step;
					found = checkGrappleStep(this, handcannon, map, dist);
				}

			}
			else //stuck -> pull towards pos
			{

				//wallrun/jump reset to make getting over things easier
				//at the top of grapple
				if (this.isOnWall()) //on wall
				{
					//close to the grapple point
					//not too far above
					//and moving downwards
					Vec2f dif = pos - handcannon.grapple_pos;
					if (this.getVelocity().y > 0 &&
					        dif.y > -10.0f &&
					        dif.Length() < 24.0f)
					{
						//need move vars
						RunnerMoveVars@ moveVars;
						if (this.get("moveVars", @moveVars))
						{
							moveVars.walljumped_side = Walljump::NONE;
						}
					}
				}

				CBlob@ b = null;
				if (handcannon.grapple_id != 0)
				{
					@b = getBlobByNetworkID(handcannon.grapple_id);
					if (b is null)
					{
						handcannon.grapple_id = 0;
					}
				}

				if (b !is null)
				{
					handcannon.grapple_pos = b.getPosition();
					if (b.isKeyJustPressed(key_action1) ||
					        b.isKeyJustPressed(key_action2) ||
					        this.isKeyPressed(key_use))
					{
						if (canSend(this) || isServer())
						{
							handcannon.grappling = false;
							SyncGrapple(this);
						}
					}
				}
				else if (shouldReleaseGrapple(this, handcannon, map))
				{
					if (canSend(this) || isServer())
					{
						handcannon.grappling = false;
						SyncGrapple(this);
					}
				}

				this.AddForce(force);
				Vec2f target = (this.getPosition() + offset);
				if (!map.rayCastSolid(this.getPosition(), target) &&
					(this.getVelocity().Length() > 2 || !this.isOnMap()))
				{
					this.setPosition(target);
				}

				if (b !is null)
					b.AddForce(-force * (b.getMass() / this.getMass()));

			}
		}

	}

}

void ManageCannon(CBlob@ this, HandcannonInfo@ handcannon, RunnerMoveVars@ moveVars)
{
	//are we responsible for this actor?
	bool ismyplayer = this.isMyPlayer();
	bool responsible = ismyplayer;
	if (isServer() && !ismyplayer)
	{
		CPlayer@ p = this.getPlayer();
		if (p !is null)
		{
			responsible = p.isBot();
		}
	}
	//
	CSprite@ sprite = this.getSprite();
	bool hasball = handcannon.has_ball;
	s8 charge_time = handcannon.charge_time;
	u8 charge_state = handcannon.charge_state;
	const bool pressed_action2 = this.isKeyPressed(key_action2);
	Vec2f pos = this.getPosition();
	bool isNotBuilding = !isBuildTime(this);

	if (responsible)
	{
		hasball = hasBalls(this);

		if (hasball != this.get_bool("has_ball"))
		{
			this.set_bool("has_ball", hasball);
			this.Sync("has_ball", isServer());
		}
	}

	if (charge_state == HandcannonParams::ignited) // fast balls
	{
		if (!hasball)
		{
			charge_state = HandcannonParams::not_aiming;
			charge_time = 0;
		}
		else
		{
			charge_state = HandcannonParams::firing;
			this.set_s32("shoot time", getGameTime() + HandcannonParams::shoot_period);
			if (responsible) this.SendCommand(this.getCommandID("sync ignite"));
		}
	}

	if (charge_state == HandcannonParams::digging)
	{
		moveVars.walkFactor *= 0.5f;
		moveVars.jumpFactor *= 0.5f;
		moveVars.canVault = false;
		handcannon.dig_delay--;
		if(handcannon.dig_delay == 0)
		{
			charge_state = HandcannonParams::not_aiming;
			if(this.isKeyPressed(key_action1) && isNotBuilding)
			{
				charge_state = HandcannonParams::igniting;
				hasball = hasBalls(this);

				if (responsible)
				{
					this.set_bool("has_ball", hasball);
					this.Sync("has_ball", isServer());
				}

				charge_time = 0;

				if (!hasball)
				{
					charge_state = HandcannonParams::no_balls;

					if (ismyplayer)   // playing annoying no ammo sound
					{
						this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
					}

				}
				else
				{
					sprite.PlaySound("SparkleShort.ogg");// fire arrow sound
				}
			}
		}
	}
	//charged - no else (we want to check the very same tick)
	else if (charge_state == HandcannonParams::firing) // based legolas system
	{
		moveVars.walkFactor *= 0.5f;

		if(charge_time < HandcannonParams::ignite_period + HandcannonParams::shoot_period) charge_time++;//for cursor
		if(!hasball || this.get_s32("shoot time") <= getGameTime())//ball lost or shoot time passed
		{
			if (this.get_s32("shoot time") == getGameTime())//just time
				ClientFire(this);

			bool pressed = this.isKeyPressed(key_action1);
			charge_state = pressed ? HandcannonParams::igniting : HandcannonParams::not_aiming;
			charge_time = 0;

			//mute fuse sound
			sprite.RewindEmitSound();
			sprite.SetEmitSoundPaused(true);
		}

	}
	else if (this.isKeyPressed(key_action1) && isNotBuilding)
	{
		moveVars.walkFactor *= 0.5f;
		moveVars.canVault = false;

		bool just_action1 = this.isKeyJustPressed(key_action1);

		//	printf("charge_state " + charge_state );
		if (hasball && charge_state == HandcannonParams::no_balls)
		{
			// (when key_action1 is down) reset charge state when:
			// * the player has picks up arrows when inventory is empty
			// * the player switches arrow type while charging bow
			charge_state = HandcannonParams::not_aiming;
			just_action1 = true;
		}

		if ((just_action1 || this.wasKeyPressed(key_action2) && !pressed_action2) &&
		        charge_state == HandcannonParams::not_aiming)
		{
			charge_state = HandcannonParams::igniting;
			hasball = hasBalls(this);

			if (responsible)
			{
				this.set_bool("has_ball", hasball);
				this.Sync("has_ball", isServer());
			}

			charge_time = 0;

			if (!hasball)
			{
				charge_state = HandcannonParams::no_balls;

				if (ismyplayer && !this.wasKeyPressed(key_action1))   // playing annoying no ammo sound
				{
					this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
				}

			}
			else
			{
				if (ismyplayer)
				{
					if (just_action1)
					{
						sprite.PlaySound("SparkleShort.ogg");// fire arrow sound
					}
				}

				sprite.RewindEmitSound();
				sprite.SetEmitSoundPaused(true);

				if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
				{
					sprite.SetEmitSoundVolume(0.5f);
				}
			}
		}
		else if (charge_state == HandcannonParams::igniting)
		{
			if(!hasball)
			{
				charge_state = HandcannonParams::no_balls;
				charge_time = 0;
				
				if (ismyplayer)   // playing annoying no ammo sound
				{
					this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
				}
			}
			else
			{
				charge_time++;
			}

			if (charge_time >= HandcannonParams::ignite_period)
			{
				// ignited, readying to shoot

				sprite.RewindEmitSound();
				sprite.SetEmitSoundPaused(false);
				charge_state = HandcannonParams::ignited;
			}
		}
		else if (charge_state == HandcannonParams::no_balls)
		{
			if (charge_time < HandcannonParams::ready_time)
			{
				charge_time++;
			}
		}
	}
	else
	{
		charge_state = HandcannonParams::not_aiming;
		charge_time = 0;
		if (pressed_action2 && isBuildTime(this))
		{
			charge_state = HandcannonParams::digging;
			handcannon.dig_delay = 25;
			DoDig(this);
		}
	}

	// my player!

	if (responsible)
	{
		// set cursor

		if (ismyplayer && !getHUD().hasButtons())
		{
			int frame = 0;
			// print("handcannon.charge_time " + handcannon.charge_time + " / " + HandcannonParams::shoot_period );
			if (handcannon.charge_state == HandcannonParams::igniting)
			{
				//readying shot
				frame = 0 + int((float(handcannon.charge_time) / float(HandcannonParams::ignite_period + 1)) * 18);
			}
			else if (handcannon.charge_state == HandcannonParams::firing || handcannon.charge_state == HandcannonParams::ignited)
			{
				//charging legolas
				frame = 18 + int((float(handcannon.charge_time - HandcannonParams::ignite_period) / float(HandcannonParams::shoot_period)) * 16);
			}
			getHUD().SetCursorFrame(frame);
		}

		// activate/throw

		if (this.isKeyJustPressed(key_action3))
		{
			client_SendThrowOrActivateCommand(this);
		}
	}


	handcannon.charge_time = charge_time;
	handcannon.charge_state = charge_state;
	handcannon.has_ball = hasball;

}

void onTick(CBlob@ this)
{
	HandcannonInfo@ handcannon;
	if (!this.get("handcannonInfo", @handcannon))
	{
		return;
	}

	if (isKnocked(this) || this.isInInventory())
	{
		handcannon.grappling = false;
		handcannon.charge_state = 0;
		handcannon.charge_time = 0;
		getHUD().SetCursorFrame(0);
		return;
	}

	ManageGrapple(this, handcannon);

	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	ManageCannon(this, handcannon, moveVars);

	if(this.isMyPlayer() && this.getCarriedBlob() is null && getBuildMode(this) == HandcannonBuilding::barricade && this.isKeyJustPressed(key_action1))// reload barricade
		this.SendCommand(this.getCommandID("barricade"));
}

bool checkGrappleBarrier(Vec2f pos)
{
	CRules@ rules = getRules();
	if (!shouldBarrier(@rules)) { return false; }

	Vec2f tl, br;
	getBarrierRect(@rules, tl, br);

	return (pos.x > tl.x && pos.x < br.x);
}

bool checkGrappleStep(CBlob@ this, HandcannonInfo@ handcannon, CMap@ map, const f32 dist)
{
	if (checkGrappleBarrier(handcannon.grapple_pos)) // red barrier
	{
		if (canSend(this) || isServer())
		{
			handcannon.grappling = false;
			SyncGrapple(this);
		}
	}
	else if (grappleHitMap(handcannon, map, dist))
	{
		handcannon.grapple_id = 0;

		handcannon.grapple_ratio = Maths::Max(0.2, Maths::Min(handcannon.grapple_ratio, dist / handcannon_grapple_length));

		handcannon.grapple_pos.y = Maths::Max(0.0, handcannon.grapple_pos.y);

		if (canSend(this) || isServer()) SyncGrapple(this);

		return true;
	}
	else
	{
		CBlob@ b = map.getBlobAtPosition(handcannon.grapple_pos);
		if (b !is null)
		{
			if (b is this)
			{
				//can't grapple self if not reeled in
				if (handcannon.grapple_ratio > 0.5f)
					return false;

				if (canSend(this) || isServer())
				{
					handcannon.grappling = false;
					SyncGrapple(this);
				}

				return true;
			}
			else if (b.isCollidable() && b.getShape().isStatic() && !b.hasTag("ignore_arrow"))
			{
				//TODO: Maybe figure out a way to grapple moving blobs
				//		without massive desync + forces :)

				handcannon.grapple_ratio = Maths::Max(0.2, Maths::Min(handcannon.grapple_ratio, b.getDistanceTo(this) / handcannon_grapple_length));

				handcannon.grapple_id = b.getNetworkID();
				if (canSend(this) || isServer())
				{
					SyncGrapple(this);
				}

				return true;
			}
		}
	}

	return false;
}

bool grappleHitMap(HandcannonInfo@ handcannon, CMap@ map, const f32 dist = 16.0f)
{
	return  map.isTileSolid(handcannon.grapple_pos + Vec2f(0, -3)) ||			//fake quad
	        map.isTileSolid(handcannon.grapple_pos + Vec2f(3, 0)) ||
	        map.isTileSolid(handcannon.grapple_pos + Vec2f(-3, 0)) ||
	        map.isTileSolid(handcannon.grapple_pos + Vec2f(0, 3)) ||
	        (dist > 10.0f && map.getSectorAtPosition(handcannon.grapple_pos, "tree") !is null);   //tree stick
}

bool shouldReleaseGrapple(CBlob@ this, HandcannonInfo@ handcannon, CMap@ map)
{
	return !grappleHitMap(handcannon, map) || this.isKeyPressed(key_use);
}

void DoDig(CBlob@ this)
{

	if (!getNet().isServer())
	{
		return;
	}

	Vec2f blobPos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f vec;
	this.getAimDirection(vec);
	Vec2f thinghy(1, 0);
	f32 aimangle = -(vec.Angle());
	if (aimangle < 0.0f)
	{
		aimangle += 360.0f;
	}
	thinghy.RotateBy(aimangle);
	vel.Normalize();
	Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	bool dontHitMoreLogs = false;
	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();
	
	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, 30.0f, radius + 16.0f, this, @hitInfos))
	{
		//HitInfo objects are sorted, first come closest hits
		// start from furthest ones to avoid doing too many redundant raycasts
		for (int i = hitInfos.size() - 1; i >= 0; i--)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;

			if (b !is null)
			{
				if (b.hasTag("ignore sword") 
				    || !canHit(this, b)) 
				{
					continue;
				}

				Vec2f hitvec = hi.hitpos - pos;

				// we do a raycast to given blob and hit everything hittable between knight and that blob
				// raycast is stopped if it runs into a "large" blob (typically a door)
				// raycast length is slightly higher than hitvec to make sure it reaches the blob it's directed at
				HitInfo@[] rayInfos;
				map.getHitInfosFromRay(pos, -(hitvec).getAngleDegrees(), hitvec.Length() + 2.0f, this, rayInfos);

				for (int j = 0; j < rayInfos.size(); j++)
				{
					CBlob@ rayb = rayInfos[j].blob;
					
					if (rayb is null) break; // means we ran into a tile, don't need blobs after it if there are any
					if (rayb.hasTag("ignore sword") || !canHit(this, rayb)) continue;

					bool large = (rayb.hasTag("blocks sword") || (rayb.hasTag("barricade") && rayb.getTeamNum() != this.getTeamNum())// added here
								 && !rayb.isAttached() && rayb.isCollidable()); // usually doors, but can also be boats/some mechanisms

					f32 temp_damage = 1.0f;
					
					if (rayb.getName() == "log")
					{
						if (!dontHitMoreLogs)
						{
							//temp_damage /= 3;
							dontHitMoreLogs = true; // set this here to prevent from hitting more logs on the same tick
							CBlob@ wood = server_CreateBlobNoInit("mat_wood");
							if (wood !is null)
							{
								int quantity = Maths::Ceil(float(temp_damage) * 20.0f);
								int max_quantity = rayb.getHealth() / 0.024f; // initial log health / max mats
								
								quantity = Maths::Max(
									Maths::Min(quantity, max_quantity),
									0
								);

								wood.Tag('custom quantity');
								wood.Init();
								wood.setPosition(rayInfos[j].hitpos);
								wood.server_SetQuantity(quantity);
							}
						}
						else 
						{
							// print("passed a log on " + getGameTime());
							continue; // don't hit the log
						}
					}

					
					Vec2f velocity = rayb.getPosition() - pos;
					velocity.Normalize();
					velocity *= 12; // knockback force is same regardless of distance

					if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
					{
						this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, Hitters::handaxe, true);
					}
					
					if (large)
					{
						break; // don't raycast past the door after we do damage to it
					}
				}
			}
			else  // hitmap
				if (!dontHitMoreMap)
				{
					bool ground = map.isTileGround(hi.tile);
					bool dirt_stone = map.isTileStone(hi.tile);
					bool dirt_thick_stone = map.isTileThickStone(hi.tile);
					bool gold = map.isTileGold(hi.tile);
					bool wood = map.isTileWood(hi.tile);
					bool stone = map.isTileCastle(hi.tile);
					if (ground || wood || dirt_stone || gold || stone)
					{
						Vec2f tpos = map.getTileWorldPosition(hi.tileOffset) + Vec2f(4, 4);
						Vec2f offset = (tpos - blobPos);
						f32 tileangle = offset.Angle();
						f32 dif = Maths::Abs(exact_aimangle - tileangle);
						if (dif > 180)
							dif -= 360;
						if (dif < -180)
							dif += 360;

						dif = Maths::Abs(dif);
						//print("dif: "+dif);

						if (dif < 20.0f)
						{
							//detect corner

							int check_x = -(offset.x > 0 ? -1 : 1);
							int check_y = -(offset.y > 0 ? -1 : 1);
							if (map.isTileSolid(hi.hitpos - Vec2f(map.tilesize * check_x, 0)) &&
							        map.isTileSolid(hi.hitpos - Vec2f(0, map.tilesize * check_y)))
								continue;


							bool canhit = map.getSectorAtPosition(tpos, "no build") is null;

							dontHitMoreMap = true;

							if (canhit)
							{
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
								if (gold)
								{
									// Note: 0.1f damage doesn't harvest anything I guess
									// This puts it in inventory - include MaterialCommon
									//Material::fromTile(this, hi.tile, 1.f);

									CBlob@ ore = server_CreateBlobNoInit("mat_gold");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
	     								ore.Init();
	     								ore.setPosition(pos);
	     								ore.server_SetQuantity(4);
	     							}
								}
								else if (dirt_stone)
								{
									int quantity = 4;
									if(dirt_thick_stone)
									{
										quantity = 6;
									}
									CBlob@ ore = server_CreateBlobNoInit("mat_stone");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
										ore.Init();
										ore.setPosition(hi.hitpos);
										ore.server_SetQuantity(quantity);
									}
								}
							}
						}
					}
				}
		}
	}
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void ClientFire(CBlob@ this)
{
	//time to fire!
	if (canSend(this))  // client-logic
	{

		this.SendCommand(this.getCommandID("request shoot"));
	}
}

CBlob@ CreateBall(CBlob@ this, Vec2f ballPos, Vec2f ballVel)
{
	CBlob@ ball = server_CreateBlobNoInit("handcannonball");
	if (ball !is null)
	{
		ball.SetDamageOwnerPlayer(this.getPlayer());
		ball.Init();

		ball.IgnoreCollisionWhileOverlapped(this);
		ball.server_setTeamNum(this.getTeamNum());
		ball.setPosition(ballPos);
		ball.setVelocity(ballVel);
	}
	return ball;
}

void ShootBall(CBlob@ this)
{
	HandcannonInfo@ handcannon;
	if (!this.get("handcannonInfo", @handcannon))
	{
		return;
	}

	if (!hasBalls(this)) return; 
	
	s8 charge_time = handcannon.charge_time;
	u8 charge_state = handcannon.charge_state;

	f32 ballspeed = HandcannonParams::shoot_max_vel;

	Vec2f offset(this.isFacingLeft() ? 2 : -2, -2);

	Vec2f ballPos = this.getPosition() + offset;
	Vec2f aimpos = this.getAimPos();
	Vec2f ballVel = (aimpos - ballPos);
	ballVel.Normalize();
	ballVel *= ballspeed;

	CreateBall(this, ballPos, ballVel);

	this.SendCommand(this.getCommandID("play fire sound"));
	this.TakeBlob("mat_handcannonballs", 1);

}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("play fire sound") && isClient())
	{
		this.getSprite().PlaySound("Bomb.ogg");
	}
	else if (cmd == this.getCommandID("request shoot") && isServer())
	{
		HandcannonInfo@ handcannon;
		if (!this.get("handcannonInfo", @handcannon)) { return; }

		ShootBall(this);
	}
	else if (cmd == this.getCommandID("sync ignite") && isServer())
	{
		HandcannonInfo@ handcannon;
		if (!this.get("handcannonInfo", @handcannon))
		{
			return;
		}
		if (handcannon.charge_state != HandcannonParams::firing)// sync shoot state
		{
			handcannon.charge_state = HandcannonParams::firing;
			handcannon.charge_time = HandcannonParams::ignite_period;
			this.set_s32("shoot time", getGameTime() + HandcannonParams::shoot_period);
			this.getSprite().SetEmitSoundPaused(false);
		}

		this.SendCommand(this.getCommandID("sync ignite client"));
	}
	else if (cmd == this.getCommandID("sync ignite client") && isClient())
	{
		HandcannonInfo@ handcannon;
		if (!this.get("handcannonInfo", @handcannon))
		{
			return;
		}
		if (handcannon.charge_state != HandcannonParams::firing)// sync shoot state
		{
			handcannon.charge_state = HandcannonParams::firing;
			handcannon.charge_time = HandcannonParams::ignite_period;
			this.set_s32("shoot time", getGameTime() + HandcannonParams::shoot_period);
			this.getSprite().SetEmitSoundPaused(false);
		}
	}
}

// as same as knight
// Blame Fuzzle.
bool canHit(CBlob@ this, CBlob@ b)
{
	if (b.hasTag("invincible") || b.hasTag("temp blob"))
		return false;
	
	// don't hit picked up items (except players and specially tagged items)
	return b.hasTag("player") || b.hasTag("slash_while_in_hand") || !isBlobBeingCarried(b);
}

bool isBlobBeingCarried(CBlob@ b)
{	
	CAttachment@ att = b.getAttachments();
	if (att is null)
	{
		return false;
	}

	// Look for a "PICKUP" attachment point where socket=false and occupied=true
	return att.getAttachmentPoint("PICKUP", false, true) !is null;
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
	string itemname = blob.getName();
	if (this.isMyPlayer())
	{
		if (itemname == "mat_handcannonballs")
		{
			SetHelp(this, "help self action", "handcannon", "$handcannonball$Fire ball   $KEY_HOLD$$LMB$", "", 255);
		}
		else if (itemname == "mat_barricades")
		{
			SetHelp(this, "help inventory", "handcannon", "$Build$Select in inventory to build barricade", "", 255);
		}
	}
}