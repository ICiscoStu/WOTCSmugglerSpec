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

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
    local X2EventManager EventMgr;
    local XComGameState_Unit UnitState;
    local Object EffectObj;

    EffectObj = EffectGameState;
    UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.SourceStateObjectRef.ObjectID));

    EventMgr = `XEVENTMGR;
    EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', FlechetteRoundActivatedEventListener, ELD_OnStateSubmitted,, UnitState,, EffectObj);
}

static function  EventListenerReturn FlechetteRoundActivatedEventListener(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameStateContext_Ability	AbilityContext;
    local XComGameState_Ability			AbilityState;
    local XComGameState_Unit			UnitState;
	local XComGameState_Effect			EffectState;
	local XComGameState                 NewGameState;
	local XComGameState_Item			WeaponState;
	local X2AbilityTemplate             AbilityTemplate;
	local bool                          bAbilityHasAmmoCost;


	EffectState = XComGameState_Effect(CallbackData);
    AbilityState = XComGameState_Ability(EventData);
    UnitState = XComGameState_Unit(EventSource);
    AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	WeaponState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(EffectState.ApplyEffectParameters.ItemStateObjectRef.ObjectID));
	AbilityTemplate = AbilityState.GetMyTemplate();

	`LOG("Everything setup and ready to change",, 'CSSmugglerSpecWOTC --------------------------------');

    if (AbilityState == none || UnitState == none || AbilityContext == none || EffectState == none || EffectState.ApplyEffectParameters.ItemStateObjectRef != AbilityState.SourceWeapon )
    {
		`LOG("We had a problem an we are exiting listener",, 'CSSmugglerSpecWOTC --------------------------------');
        return ELR_NoInterrupt;
    }

	if (AbilityContext.InterruptionStatus == eInterruptionStatus_Interrupt)
    {
		`LOG("At the interruption stage",, 'CSSmugglerSpecWOTC --------------------------------');
		Return ELR_NoInterrupt;
    }
    else
    {
		bAbilityHasAmmoCost = AbilityHasAmmoCost(AbilityTemplate);
		if (bAbilityHasAmmoCost)
		{

			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState();
			WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', WeaponState.ObjectID));

			// Restore the previous ammo type
			`LOG("we have a weaponSttee and we are outside the interruption stage, my current loaded ammo id is:" @ WeaponState.LoadedAmmo.ObjectID,, 'CSSmugglerSpecWOTC --------------------------------');

			WeaponState.LoadedAmmo.ObjectID = EffectState.GrantsThisTurn;			

			`LOG("we have updated the loaded ammo to this id:" @ WeaponState.LoadedAmmo.ObjectID,, 'CSSmugglerSpecWOTC --------------------------------');
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}		
    }

    return ELR_NoInterrupt;
}

static function bool AbilityHasAmmoCost(const X2AbilityTemplate Template)
{
    local X2AbilityCost                   Cost;
    local X2AbilityCost_Ammo              AmmoCost;
    local bool                            bAbilityHasAmmoCost;

    foreach Template.AbilityCosts(Cost)
    {
        AmmoCost = X2AbilityCost_Ammo(Cost);

        if (AmmoCost != none)
        {
            bAbilityHasAmmoCost = true;
        } 
    }
    return bAbilityHasAmmoCost;
}

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
    local XComGameState_Unit		UnitState;
	local XComGameState_Item		WeaponState, AmmoState;
	local StateObjectReference		ReloadSawedOffRef;
	local XComGameState_Ability		ReloadSawedOffAbility;
	local int						ClipSize;
	local X2ItemTemplate			AmmoTemplate;

	UnitState = XComGameState_Unit(kNewTargetState);

    if (UnitState != none)
    {
		WeaponState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.ItemStateObjectRef.ObjectID));
		if (WeaponState != none)
		{
			ClipSize = WeaponState.GetClipSize();
			//	If weapon's Ammo is not full, then load +1 Ammo
			if (WeaponState.Ammo < ClipSize)
			{
				WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ApplyEffectParameters.ItemStateObjectRef.ObjectID));

				// create the ammo
				AmmoTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate('FlechetteRounds');
				AmmoState = AmmoTemplate.CreateInstanceFromTemplate(NewGameState);

				NewEffectState.GrantsThisTurn = WeaponState.LoadedAmmo.ObjectID;
				WeaponState.LoadedAmmo = AmmoState.GetReference();
				`LOG("we have updated the loaded ammo to this id:" @ WeaponState.LoadedAmmo.ObjectID,, 'CSSmugglerSpecWOTC --------------------------------');

				// reload ammo
				WeaponState.Ammo += AmmoToReload;
				if (WeaponState.Ammo > ClipSize)
				{
					  WeaponState.Ammo = ClipSize;
				}
			}
			else
			{	
				//	If weapon is already at full ammo, grant +1 Charge to Reload Sawed Off ability.
				ReloadSawedOffRef = UnitState.FindAbility('RpgSawnOffReload');
				if(ReloadSawedOffRef.ObjectID > 0)
				{
					ReloadSawedOffAbility = XComGameState_Ability(NewGameState.ModifyStateObject(ReloadSawedOffAbility.Class, ReloadSawedOffRef.ObjectID));
					if(ReloadSawedOffAbility != none)
					{
						ReloadSawedOffAbility.iCharges += AmmoToReload;
					}	
				} 
			}
			
		}
    }
    super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}