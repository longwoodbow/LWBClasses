// Pikeman animations

#include "PikemanCommon.as"
#include "FireParticle.as"
#include "RunnerAnimCommon.as";
#include "RunnerCommon.as";
#include "KnockedCommon.as";
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "Accolades.as"
#include "CrouchCommon.as";

const string shiny_layer = "shiny bit";

void onInit(CSprite@ this)
{
	LoadSprites(this);
}

void onPlayerInfoChanged(CSprite@ this)
{
	LoadSprites(this);
}

void LoadSprites(CSprite@ this)
{
	int armour = PLAYER_ARMOUR_STANDARD;

	CPlayer@ p = this.getBlob().getPlayer();
	if (p !is null)
	{
		armour = p.getArmourSet();
		if (armour == PLAYER_ARMOUR_STANDARD)
		{
			Accolades@ acc = getPlayerAccolades(p.getUsername());
			if (acc.hasCape())
			{
				armour = PLAYER_ARMOUR_CAPE;
			}
		}
	}

	switch (armour)
	{
	case PLAYER_ARMOUR_STANDARD:
		ensureCorrectRunnerTexture(this, "pikeman", "Pikeman");
		break;
	case PLAYER_ARMOUR_CAPE:
		ensureCorrectRunnerTexture(this, "pikeman_cape", "PikemanCape");
		break;
	case PLAYER_ARMOUR_GOLD:
		ensureCorrectRunnerTexture(this, "pikeman_gold",  "PikemanGold");
		break;
	}
	
	string texname = getRunnerTextureName(this);

	// add blade
	this.RemoveSpriteLayer("thrust");
	CSpriteLayer@ thrust = this.addTexturedSpriteLayer("thrust", this.getTextureName(), 64, 64);

	if (thrust !is null)
	{
		Animation@ anim = thrust.addAnimation("default", 0, true);
		anim.AddFrame(35);
		anim.AddFrame(43);
		anim.AddFrame(63);
		thrust.SetVisible(false);
		thrust.SetRelativeZ(1000.0f);
	}

	// add blade
	this.RemoveSpriteLayer("chop");
	CSpriteLayer@ chop = this.addTexturedSpriteLayer("chop", this.getTextureName(), 64, 64);

	if (chop !is null)
	{
		Animation@ anim = chop.addAnimation("default", 0, true);
		anim.AddFrame(56);
		anim.AddFrame(57);
		anim.AddFrame(58);
		chop.SetVisible(false);
		chop.SetRelativeZ(1000.0f);
	}

	// add shiny
	this.RemoveSpriteLayer(shiny_layer);
	CSpriteLayer@ shiny = this.addSpriteLayer(shiny_layer, "AnimeShiny.png", 16, 16);

	if (shiny !is null)
	{
		Animation@ anim = shiny.addAnimation("default", 2, true);
		int[] frames = {0, 1, 2, 3};
		anim.AddFrames(frames);
		shiny.SetVisible(false);
		shiny.SetRelativeZ(1.0f);
	}
}

void onTick(CSprite@ this)
{
	// store some vars for ease and speed
	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f aimpos;

	PikemanInfo@ pikeman;
	if (!blob.get("pikemanInfo", @pikeman))
	{
		return;
	}

	bool knocked = isKnocked(blob);

	bool pikeState = isPikeState(pikeman.state);

	bool pressed_a1 = blob.isKeyPressed(key_action1);
	bool pressed_a2 = blob.isKeyPressed(key_action2);

	bool walking = (blob.isKeyPressed(key_left) || blob.isKeyPressed(key_right));
	bool crouching = isCrouching(blob);

	aimpos = blob.getAimPos();
	bool inair = (!blob.isOnGround() && !blob.isOnLadder());

	Vec2f vel = blob.getVelocity();

	if (blob.hasTag("dead"))
	{
		if (this.animation.name != "dead")
		{
			this.RemoveSpriteLayer(shiny_layer);
			this.SetAnimation("dead");
		}
		Vec2f oldvel = blob.getOldVelocity();

		//TODO: trigger frame one the first time we server_Die()()
		if (vel.y < -1.0f)
		{
			this.SetFrameIndex(1);
		}
		else if (vel.y > 1.0f)
		{
			this.SetFrameIndex(3);
		}
		else
		{
			this.SetFrameIndex(2);
		}

		CSpriteLayer@ thrust = this.getSpriteLayer("thrust");

		if (thrust !is null)
		{
			thrust.SetVisible(false);
		}

		CSpriteLayer@ chop = this.getSpriteLayer("chop");

		if (chop !is null)
		{
			chop.SetVisible(false);
		}

		return;
	}

	// get the angle of aiming with mouse
	Vec2f vec;
	int direction = blob.getAimDirection(vec);

	// set facing
	bool facingLeft = this.isFacingLeft();
	// animations
	bool ended = this.isAnimationEnded();
	bool wantsThrustLayer = false;
	s32 thrustframe = 0;
	f32 thrustAngle = 0.0f;
	bool wantsChopLayer = false;
	s32 chopframe = 0;
	f32 chopAngle = 0.0f;


	const bool left = blob.isKeyPressed(key_left);
	const bool right = blob.isKeyPressed(key_right);
	const bool up = blob.isKeyPressed(key_up);
	const bool down = blob.isKeyPressed(key_down);

	bool shinydot = false;

	if (knocked)
	{
		if (inair)
		{
			this.SetAnimation("knocked_air");
		}
		else
		{
			this.SetAnimation("knocked");
		}
	}
	else if (blob.hasTag("seated"))
	{
		this.SetAnimation("crouch");
	}
	else
	{
		switch(pikeman.state)
		{
			case PikemanStates::resheathing_slash:
				this.SetAnimation("resheath_slash");
			break;
			
			case PikemanStates::resheathing_cut:
			case PikemanStates::resheathing_thrust:
				this.SetAnimation(crouching ? "draw_pike_crouched" : "draw_pike");
			break;

			case PikemanStates::pike_cut_mid:
				this.SetAnimation("strike_mid");
			break;

			case PikemanStates::pike_cut_mid_down:
				this.SetAnimation("strike_mid_down");
			break;

			case PikemanStates::pike_cut_up:
				this.SetAnimation("strike_up");
			break;

			case PikemanStates::pike_cut_down:
				this.SetAnimation("strike_down");
			break;

			case PikemanStates::pike_thrust:
			case PikemanStates::pike_thrust_super:
			{
				if((this.isAnimation("strike_mid") ||
					this.isAnimation("strike_mid_down") ||
					this.isAnimation("strike_up") ||
					this.isAnimation("strike_down"))
					 && pikeman.pikeTimer != 0)
					this.SetAnimation(this.animation.name);// keep showing this animation
				else
				{
					if (direction == -1)
					{
						this.SetAnimation("strike_up");
					}
					else if (direction == 0)
					{
						if (aimpos.y < pos.y)
						{
							this.SetAnimation("strike_mid");
						}
						else
						{
							this.SetAnimation("strike_mid_down");
						}
					}
					else
					{
						this.SetAnimation("strike_down");
					}
				}


				if (pikeman.pikeTimer <= 1)
					this.animation.SetFrameIndex(0);

				u8 mintime = 6;
				u8 maxtime = 8;
				if (pikeman.pikeTimer >= mintime && pikeman.pikeTimer <= maxtime)
				{
					wantsThrustLayer = true;
					thrustframe = pikeman.pikeTimer - mintime;
					thrustAngle = -vec.Angle();
				}
			}
			break;

			case PikemanStates::pike_slash:
			{
				this.SetAnimation("slash");

				if (pikeman.pikeTimer <= 1)
					this.animation.SetFrameIndex(0);

				u8 mintime = 6;
				u8 maxtime = 8;
				if (pikeman.pikeTimer >= mintime && pikeman.pikeTimer <= maxtime)
				{
					wantsChopLayer = true;
					chopframe = pikeman.pikeTimer - mintime;
					chopAngle = -vec.Angle();
				}
			}
			break;

			case PikemanStates::pike_drawn:
			{
				if ((!pikeman.isSlash && pikeman.pikeTimer < PikemanVars::thrust_charge) ||
					(pikeman.isSlash && pikeman.pikeTimer < PikemanVars::slash_charge))
				{
					this.SetAnimation(crouching ? "draw_pike_crouched" : "draw_pike");
				}
				else if (!pikeman.isSlash && pikeman.pikeTimer < PikemanVars::thrust_charge_level2)
				{
					this.SetAnimation(crouching ? "strike_power_ready_crouched" : "strike_power_ready");
					this.animation.frame = 0;
				}
				else if (!pikeman.isSlash && pikeman.pikeTimer < PikemanVars::thrust_charge_limit)
				{
					this.SetAnimation(crouching ? "strike_power_ready_crouched" : "strike_power_ready");
					this.animation.frame = 1;
					shinydot = true;
				}
				else if (pikeman.isSlash && pikeman.pikeTimer < PikemanVars::slash_charge_limit)
				{
					this.SetAnimation(crouching ? "strike_power_ready_crouched" : "strike_power_ready");
					this.animation.frame = 2;
				}
				else
				{
					this.SetAnimation(crouching ? "draw_pike_crouched" : "draw_pike");
				}
			}
			break;

			default:
			{
				if (inair)
				{
					RunnerMoveVars@ moveVars;
					if (!blob.get("moveVars", @moveVars))
					{
						return;
					}
					f32 vy = vel.y;
					if (vy < -0.0f && moveVars.walljumped)
					{
						this.SetAnimation("run");
					}
					else
					{
						this.SetAnimation("fall");
						this.animation.timer = 0;
						bool inwater = blob.isInWater();

						if (vy < -1.5 * (inwater ? 0.7 : 1))
						{
							this.animation.frame = 0;
						}
						else if (vy > 1.5 * (inwater ? 0.7 : 1))
						{
							this.animation.frame = 2;
						}
						else
						{
							this.animation.frame = 1;
						}
					}
				}
				else if (walking || 
					(blob.isOnLadder() && (blob.isKeyPressed(key_up) || blob.isKeyPressed(key_down))))
				{
					this.SetAnimation("run");
				}
				else
				{
					defaultIdleAnim(this, blob, direction);
				}
			}
		}
	}

	CSpriteLayer@ thrust = this.getSpriteLayer("thrust");

	if (thrust !is null)
	{
		thrust.SetVisible(wantsThrustLayer);
		if (wantsThrustLayer)
		{
			f32 thrustlength = 40.0f; // quad

			thrust.animation.frame = thrustframe;
			Vec2f offset = Vec2f(thrustlength, 0.0f);
			offset.RotateBy(thrustAngle, Vec2f_zero);
			if (!this.isFacingLeft())
				offset.x *= -1.0f;
			offset.y += this.getOffset().y * 0.5f;

			thrust.SetOffset(offset);
			thrust.ResetTransform();
			if (this.isFacingLeft())
				thrust.RotateBy(180.0f + thrustAngle, Vec2f());
			else
				thrust.RotateBy(thrustAngle, Vec2f());
		}
	}

	CSpriteLayer@ chop = this.getSpriteLayer("chop");

	if (chop !is null)
	{
		chop.SetVisible(wantsChopLayer);
		if (wantsChopLayer)
		{
			f32 choplength = 5.0f;

			chop.animation.frame = chopframe;
			Vec2f offset = Vec2f(choplength, 0.0f);
			offset.RotateBy(chopAngle, Vec2f_zero);
			if (!this.isFacingLeft())
				offset.x *= -1.0f;
			offset.y += this.getOffset().y * 0.5f;

			chop.SetOffset(offset);
			chop.ResetTransform();
			if (this.isFacingLeft())
				chop.RotateBy(180.0f + chopAngle, Vec2f());
			else
				chop.RotateBy(chopAngle, Vec2f());
		}
	}

	//set the shiny dot on the pike

	CSpriteLayer@ shiny = this.getSpriteLayer(shiny_layer);

	if (shiny !is null)
	{
		shiny.SetVisible(shinydot);
		if (shinydot)
		{
			f32 range = (PikemanVars::thrust_charge_limit - PikemanVars::thrust_charge_level2);
			f32 count = (pikeman.pikeTimer - PikemanVars::thrust_charge_level2);
			f32 ratio = count / range;
			shiny.RotateBy(10, Vec2f());
			shiny.SetOffset(Vec2f(12, -2 + ratio * 8));
		}
	}

	//set the head anim
	if (knocked)
	{
		blob.Tag("dead head");
	}
	else if (blob.isKeyPressed(key_action1))
	{
		blob.Tag("attack head");
		blob.Untag("dead head");
	}
	else
	{
		blob.Untag("attack head");
		blob.Untag("dead head");
	}

}

void onGib(CSprite@ this)
{
	if (g_kidssafe)
	{
		return;
	}

	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f vel = blob.getVelocity();
	vel.y -= 3.0f;
	f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.0f;
	const u8 team = blob.getTeamNum();
	CParticle@ Body     = makeGibParticle("Entities/Characters/Pikeman/PikemanGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm      = makeGibParticle("Entities/Characters/Pikeman/PikemanGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Shield   = makeGibParticle("Entities/Characters/Pikeman/PikemanGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Sword    = makeGibParticle("Entities/Characters/Pikeman/PikemanGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
}


// render cursors

void DrawCursorAt(Vec2f position, string& in filename)
{
	position = getMap().getAlignedWorldPos(position);
	if (position == Vec2f_zero) return;
	position = getDriver().getScreenPosFromWorldPos(position - Vec2f(1, 1));
	GUI::DrawIcon(filename, position, getCamera().targetDistance * getDriver().getResolutionScaleFactor());
}

const string cursorTexture = "Entities/Characters/Sprites/TileCursor.png";

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if (!blob.isMyPlayer())
	{
		return;
	}
	if (getHUD().hasButtons())
	{
		return;
	}

	// draw tile cursor

	if (blob.isKeyPressed(key_action1) || blob.isKeyPressed(key_action2))
	{
		CMap@ map = blob.getMap();
		Vec2f position = blob.getPosition();
		Vec2f cursor_position = blob.getAimPos();
		Vec2f surface_position;
		map.rayCastSolid(position, cursor_position, surface_position);
		Vec2f vector = surface_position - position;
		f32 distance = vector.getLength();
		Tile tile = map.getTile(surface_position);

		if ((map.isTileSolid(tile) || map.isTileGrass(tile.type)) && map.getSectorAtPosition(surface_position, "no build") is null && distance < 45.0f)
		{
			DrawCursorAt(surface_position, cursorTexture);
		}
	}
}
