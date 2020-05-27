class X2Effect_Flechette_Round extends X2Effect_Persistent;

var int AmmoToReload;

function int GetExtraArmorPiercing(XComGameState_Effect EffectState, XComGameState_Unit Attacker, Damageable TargetDamageable, XComGameState_Ability AbilityState, const out EffectAppliedData AppliedData)
{
	return 0;
}

function int GetExtraShredValue(XComGameState_Effect EffectState, XComGameState_Unit Attacker, Damageable TargetDamageable, XComGameState_Ability AbilityState, const out EffectAppliedData AppliedData)
{
	return 0;
}

//function int GetAttackingDamageModifier(XComGameState_Effect EffectState, XComGameState_Unit Attacker, Damageable TargetDamageable, XComGameState_Ability AbilityState, const out EffectAppliedData AppliedData, const int CurrentDamage, optional XComGameState NewGameState)
//{ 
	//local XComGameState_Item	ItemState;
	//local X2AbilityTemplate		AbilityTemplate;
	//local XComGameState_Player	Player;
//
	//ItemState = AbilityState.GetSourceWeapon();
	//AbilityTemplate = AbilityState.GetMyTemplate();
//
	//if (ItemState != none && ItemState.ObjectID == AppliedData.ItemStateObjectRef.ObjectID)
	//{
		//if (NewGameState != none)
		//{
			//Player = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(EffectState.ApplyEffectParameters.PlayerStateObjectRef.ObjectID));
			//if (Player != none)
			//{
				//`XEVENTMGR.TriggerEvent('CS_Flechette_Round_Consumed', Player, Attacker, NewGameState);
			//}
		//}
		//return 1; 
	//}
	//else return 0;
//}

//function RegisterForEvents(XComGameState_Effect EffectGameState)
//{
	//local X2EventManager		EventMgr;
	//local XComGameState_Player	PlayerState;
	//local Object				EffectObj;
//
	//EventMgr = `XEVENTMGR;
//
	//EffectObj = EffectGameState;
	//PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.PlayerStateObjectRef.ObjectID));
//
	//EventMgr.RegisterForEvent(EffectObj, 'PlayerTurnBegun', BreakBind_Listener, ELD_OnStateSubmitted,, PlayerState,, EffectGameState);
	//EventMgr.UnRegisterFromEvent(EffectObj, 'PlayerTurnEnded');
	//EventMgr.RegisterForEvent(EffectObj, 'CS_Flechette_Round_Consumed', OnPlayerTurnTickedWrapper, ELD_OnStateSubmitted,,,, EffectGameState);
//}

//function bool IsEffectCurrentlyRelevant(XComGameState_Effect EffectGameState, XComGameState_Unit TargetUnit)
//{
    //local UnitValue UV;
//
    //TargetUnit.GetUnitValue(default.SunderArmorUnitValue, UV);
//
    //return UV.fValue > 0;
//}

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
    local XComGameState_Unit				UnitState;
	local XComGameState_Item				WeaponState, NewWeaponState;
	local StateObjectReference				ReloadSawedOffRef;
	local XComGameState_Ability				ReloadSawedOffAbility;
	local int								ClipSize;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	if (UnitState == none)
	{
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	}

    if (UnitState != none)
    {
		WeaponState = XComGameState_Item(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.ItemStateObjectRef.ObjectID));
		if (WeaponState == none)
		{
			WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Unit', ApplyEffectParameters.ItemStateObjectRef.ObjectID));
		}

		if (WeaponState != none)
		{
			NewWeaponState = XComGameState_Item(NewGameState.ModifyStateObject(WeaponState.Class, WeaponState.ObjectID));
			ClipSize = WeaponState.GetClipSize();

			NewWeaponState.Ammo += AmmoToReload;
            if(NewWeaponState.Ammo > ClipSize)
            {
                  NewWeaponState.Ammo = ClipSize;
            }
			else
			{
				ReloadSawedOffRef = UnitState.FindAbility('RpgSawnOffReload');
				if(ReloadSawedOffRef.ObjectID > 0)
				{
					ReloadSawedOffAbility = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(ReloadSawedOffRef.ObjectID));
					if(ReloadSawedOffAbility != none)
					{
						ReloadSawedOffAbility = XComGameState_Ability(NewGameState.ModifyStateObject(ReloadSawedOffAbility.Class, ReloadSawedOffAbility.ObjectID));
						ReloadSawedOffAbility.iCharges += AmmoToReload;
					}	
				}
			}
		}
    }
    super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}