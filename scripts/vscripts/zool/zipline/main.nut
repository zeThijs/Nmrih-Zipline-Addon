/*====================================================================
			__________.__       .__  .__               
			\____    /|__|_____ |  | |__| ____   ____  
			  /     / |  \____ \|  | |  |/    \_/ __ \ 
			 /     /_ |  |  |_> >  |_|  |   |  \  ___/ 
			/_______ \|__|   __/|____/__|___|  /\___  >
					\/   |__|                \/     \/ 
					
									by @ZooL_Smith
									port nmrih zeThijs
====================================================================*/

const SCRIPT_NAME = "ZipLine, by @ZooL_Smith and zeThijs";

/*	Theory of operation:
 * 	Buttons Are spawned all along a rope track. This creates a zipline.
 *	The player may perform use on this zipline, after which they are zipped
 *	From one end of the zipline to the other.
*/

::zipline_script <- this;
IncludeScript("zool/zipline/config.nut");
zipgrab_maker <- EntityGroup[0].GetScriptScope();

::ziplines <- [];

Zipline <- class
{
	name = "unknown";
	start = null;
	end = null;
	curve = null;
	oneway = false;
	
	constructor(name, start, end, oneway)
	{
		this.name = name;
		this.start = start;
		this.end = end;
		this.curve = start.GetHealth();
		this.oneway = oneway;
	}
}

// Make Ziplines on spawn
function OnPostSpawn()
{
	if (zippopulateonload)
		PopulateZiplines()	
}

// Each zipline need to be a move_rope and have _s and _e at the end of their targename to be used used
function PopulateZiplines()
{

	printcl(100,100,200,"----------------------------")
	printcl(100,100,200, SCRIPT_NAME)
	printcl(100,100,200,"Setting up ziplines..")
	printcl(100,100,200,"----------------------------")
	local start = null;
	while(start = Entities.FindByClassname(start, "move_rope"))
	{
		local startname = start.GetName();
		local startlen = startname.len();
		local oneway = false;
		if(startlen > 2 && startname[startlen-2] == '_' && startname[startlen-1] == 's')
		{
			local end = Entities.FindByName(null, startname.slice(0, startlen-2)+"_e");
			if(end == null)
			{
				end = Entities.FindByName(null, startname.slice(0, startlen-2)+"_ee");
				if(end == null)
					continue;
				oneway = true;
			}
			
			buildZipline(Zipline(startname.slice(0, startlen-2), start, end, oneway));
		}
	}
}

// Find a spawned Zipline by targetname
::FindZipline <- function(name)
{

	foreach(z in ziplines)
		if (z==null)
			return null;
		else if(z.name == name)
			return z;

	printl("ERROR: Couldn't find zipline named "+name);
	return null;
}

function setCurve(name, curve)
{
	local z = FindZipline(name);
	if(!z) return;
	z.start.__KeyValueFromInt("health", curve);
	z.curve = curve;
} 
::zip_setCurve<-function(name,curve){zipline_script.setCurve(name, curve)}

// The function that spawns the func_buttons and append the zipline
// Only use this manually on templated ziplines
// Builds a zipline class object. Ingame entities include 2 ropes and two buttons 
function buildZipline(zipline)
{
	local len = (zipline.start.GetOrigin() - zipline.end.GetOrigin()).Length();
	for(local i = 0; i < len; i+=zipblobdist)
	{
		zipgrab_maker.spawnAt(zipline.name, ficoolquad(zipline.start, zipline.end, i, zipline.curve));
	}
	ziplines.append(zipline);	

	/*
		Why did i add this again? lol
	*/	
	local ent = null;
	local i = 0
	while(( ent = Entities.FindByName(ent, "zipgrab_button" )) != null){
		local name = zipline_templatename;
		ent.SetName(name);
		// ent.AddOutput("OnPressed", "script_zipline", "RunScriptCode", "Use()", 0, -1);
        local scope = ent.GetOrCreatePrivateScriptScope();
        scope.InputUse  <- function() 
        {
			if(!activator || activator.GetClassname() != "player"){
				return;
			}			
			::UseZipline(activator, self)
        }
		i++;
		EntFireByHandle(ent, "DisableDraw", "", 0, null, null);
		EntFireByHandle(ent, "addoutput", "Solid 0", 0.0,null,null);  
	}
}

// WARNING: Since move_rope is in the respawn blacklist, it wont be recreated the next round!
// Only use this manually on templated ziplines
function destroyZipline(name)
{
	local zip = -1;
	for(local i = 0; i<ziplines.len(); i++)
	{
		if(ziplines[i].name == name)
		{
			zip = i;
			break;
		}
	}
	if(zip == -1)
		return;

	EntFire(ziplines[zip].name, "Kill");
	EntFire(ziplines[zip].name+"_*", "Break");
	ziplines.remove(zip);
}

// Precache the sounds
function Precache()
{
	self.PrecacheSoundScript("Survival.DropzonePullRipcord");
	self.PrecacheSoundScript("Survival.DropzoneRappell");
	self.PrecacheSoundScript("Chain.ImpactHard");
}

// When the func_button of the spawned zipline is pressed
::UseZipline <- function(user, caller)
{

	
	local callername = caller.GetName();
	local z = FindZipline(callername);
	if(z == null)
		return;
	
	activator.ValidateScriptScope();
	local scope = activator.GetScriptScope();
	if(!scope.rawin("zipline"))
	{
		scope.zipline <- {};
		scope.zipline.current <- null;
		scope.zipline.gameui <- null;
	}
	
	if(scope.zipline.current == callername)
		return;
	
	// Get the angles to snap to the end of the zipline
	local a = lookat(z.start.GetOrigin(), z.end.GetOrigin());
	local b = lookat(z.end.GetOrigin(), z.start.GetOrigin());
	
	local checkup = (z.start.GetOrigin() - z.end.GetOrigin());
	checkup.z = abs(checkup.z);
	checkup.Norm()
	
	local lookdir = null;
	local movedir = null;
	
	if(checkup.z > 0.95)
	{
		lookdir = a;
		movedir = (z.end.GetOrigin() - z.start.GetOrigin());
	}
	else if(((activator.GetAngles() - a).Length() > 90 && (activator.GetAngles() - a).Length() < 270) && z.oneway == false)
	{
		lookdir = b;
		movedir = (z.start.GetOrigin() - z.end.GetOrigin());
	}
	else
	{
		lookdir = a;
		movedir = (z.end.GetOrigin() - z.start.GetOrigin());
	}
	movedir.Norm()
	//	activator.SetAngles(lookdir.x, lookdir.y, 0);	// too annoying
	startMovePlayer(activator, callername, movedir, lookdir == a ? z.start : z.end, lookdir == a ? z.end : z.start, z.curve);	// big hackerino
}

::PlayerJump <- function()
{
	activator.GetScriptScope().zipline.leaveZip();
}

::startMovePlayer <- function(ply, name, movedir, startpoint, endpoint, curve)
{

	local scope = ply.GetScriptScope()
	local scopez = scope.zipline;
	scopez.self <- scope.self;
	if(scopez.current != null)
		return;
	
	if(scopez.gameui == null || !scopez.gameui.IsValid())
	{
		scopez.gameui = Entities.CreateByClassname("game_ui");
		scopez.gameui.__KeyValueFromInt("spawnflags", 256)	// jump disables it
		scopez.gameui.__KeyValueFromInt("FieldOfView", -1)
		EntFireByHandle(scopez.gameui, "AddOutput", "PlayerOff "+name+":RunScriptCode:PlayerJump():0:-1",0, null, null)
		scopez.gameui.SetOwner(ply);
	}
	
	scopez.current <- name;
	scopez.movedir <- movedir;
	scopez.curve <- curve;
	scopez.startpoint <- startpoint;
	scopez.endpoint <- endpoint;
	scopez.main <- this;
	scopez.jumped <- true;
	scopez.length <- (startpoint.GetOrigin() - endpoint.GetOrigin()).Length();
	scopez.progress <- (startpoint.GetOrigin() - ply.GetOrigin()).Length();
	scopez.isvertical <- fabs(movedir.z) > 0.80;
	scopez.heightoffset <- scopez.isvertical?16:zipheight;
	
	ply.EmitSound("Survival.DropzonePullRipcord");
	ply.EmitSound("Survival.DropzoneRappell");
	
	EntFireByHandle(scopez.gameui, "Activate", "", 0, ply, ply);
	
	ply.SetOrigin(ply.GetOrigin()+Vector(0,0,16));
	

	scopez.leaveZip<-function()
	{
		if(jumped && !zipcandrop)
		{
			EntFireByHandle(gameui, "Activate", "", 0, self, self);
			return;
		}
		
		if(jumped)
			self.SetVelocity(self.GetForwardVector()*40*(main.zipspeed) + Vector(0,0,400))
		
		self.StopSound("Survival.DropzonePullRipcord");
		self.StopSound("Survival.DropzoneRappell");
		self.EmitSound("Chain.ImpactHard");
		current = null;
		checkInsidePlayer();
	}
	
	scopez.checkInsidePlayer <- function()
	{
		local plyCount = 0;
		foreach(c in ["player", "cs_bot"])
		{
			local ply = null;
			while(ply = Entities.FindByClassnameWithin(ply, c, self.GetOrigin()+Vector(0,0,16), 16))
			{
				if(ply != self)
					plyCount++;
			}
			ply = null;
			while(ply = Entities.FindByClassnameWithin(ply, c, self.GetOrigin()+Vector(0,0,56), 16))
			{
				if(ply != self)
					plyCount++;
			}
		}
		if(plyCount > 0)
		{
			EntFireByHandle(self, "RunScriptCode", "zipline.checkInsidePlayer()", 0.1, null, null);
			self.SetOrigin(self.GetOrigin()-movedir*20);
			return;
		}
	}
	
	scopez.movePlayer <- function()
	{
		progress += main.zipspeed; 
		
		if(progress < length-(isvertical?75:20) /*&& (!main.isCrouching(self) || !zipcandrop)*/)
		{
			//Moves player one frame
			if(current)
			{
				local newPos = main.ficoolquad(startpoint, endpoint, progress, curve);
				local lerpedNewPos = main.lerpVector(self.GetOrigin()+Vector(0,0,heightoffset), newPos, 0.3)
				
				self.SetOrigin(lerpedNewPos - Vector(0,0,heightoffset));
				self.SetVelocity(Vector(0,0,0));
				EntFireByHandle(self, "RunScriptCode", "zipline.movePlayer()", 0.01, null, null);
			}
		}
		else
		{
			if(movedir.z > 0.95)
				self.SetVelocity(self.GetForwardVector()*40*(main.zipspeed))
			else
				self.SetVelocity(movedir*40*(main.zipspeed))
			
			jumped = false;
			scopez.leaveZip();
			EntFireByHandle(gameui, "Deactivate", "", 0, self, self);
		}
	}
	scopez.movePlayer();
}

::ficoolquad <- function(start, end, progress, curve)
{
	local p0 = start.GetOrigin();
	local p1 = ((start.GetOrigin() + end.GetOrigin()) * 0.5)-Vector(0,0,curve);
	local p2 = end.GetOrigin();
	
	local t = progress / (p0-p2).Length();
	
	local pos = p0 * ((1-t) * (1-t)) + p1 * 2 * (1-t) * t + p2 * (t*t);

	return pos;
}

::isCrouching <- function(ply)
{
	return (ply.EyePosition()-ply.GetOrigin()).z < 60;	
}

::lookat <- function(vec1, vec2)
{
	local dist = vec2-vec1;
	return Vector(57.29577951 * atan2(-dist.z, dist.Length2D()), 57.29577951 * atan2(dist.y, dist.x),0);
}
::lerp <- function(a, b, f)
{
    return a + f * (b - a);
}
::lerpVector <- function(a, b, f)
{
    return Vector(lerp(a.x,b.x,f),lerp(a.y,b.y,f),lerp(a.z,b.z,f));
}