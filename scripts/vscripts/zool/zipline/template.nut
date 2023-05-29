/*====================================================================
			__________.__       .__  .__               
			\____    /|__|_____ |  | |__| ____   ____  
			  /     / |  \____ \|  | |  |/    \_/ __ \ 
			 /     /_ |  |  |_> >  |_|  |   |  \  ___/ 
			/_______ \|__|   __/|____/__|___|  /\___  >
					\/   |__|                \/     \/ 
					
									by @ZooL_Smith
====================================================================*/

function PreSpawnInstance( entityClass, entityName ){}

function PostSpawn( entities )
{		
	foreach( name, handle in entities )
	{
		entities.zipgrab_button.__KeyValueFromString("targetname", zipline_templatename);
		EntFireByHandle(entities.zipgrab_button, "DisableDraw", "", 0, null, null);
	}
}