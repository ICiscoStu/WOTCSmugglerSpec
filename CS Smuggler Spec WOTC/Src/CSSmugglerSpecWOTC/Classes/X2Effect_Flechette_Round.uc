class X2Effect_Flechette_Round extends X2Effect_Persistent;

var int AmmoToReload;

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
			//	## Load Flechette Ammo into the weapon.

			//	Grab the Item State of the weapon from the New Game State, if it exists there. Set it up for modification, if it doesn't.
			WeaponState = XComGameState_Item(NewGameState.GetGameStateForObjectID(WeaponState.ObjectID));
			if (WeaponState == none)
			{
				WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ApplyEffectParameters.ItemStateObjectRef.ObjectID));
			}

			//	Record the Object ID of the ammo loaded into the weapon.
			//	We don't care if there's actually any special ammo loaded. If the ObjectID is zero, then we record zero.
			//	We will restore this ObjectID after one weapon shot.
			NewEffectState.GrantsThisTurn = WeaponState.LoadedAmmo.ObjectID;

			// Create new instance of Flechette Ammo and load it into the weapon.
			AmmoTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate('FlechetteRounds');
			AmmoState = AmmoTemplate.CreateInstanceFromTemplate(NewGameState);
			`LOG("OnEffectAdded, old ammo:" @ WeaponState.LoadedAmmo.ObjectID @ "new ammo:" @ AmmoState.ObjectID,, 'CSSmugglerSpecWOTC --------------------------------');
			WeaponState.LoadedAmmo = AmmoState.GetReference();

			//	## Reload Ammo into the weapon.
			ClipSize = WeaponState.GetClipSize();
			//	If weapon's Ammo is not full, then load +1 Ammo
			if (WeaponState.Ammo < ClipSize)
			{
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

static function EventListenerReturn FlechetteRoundActivatedEventListener(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameStateContext_Ability	AbilityContext;
    local XComGameState_Ability			AbilityState;
	local XComGameState_Effect			EffectState;
	local XComGameState                 NewGameState;
	local XComGameState_Item			WeaponState;

	EffectState = XComGameState_Effect(CallbackData);
    AbilityState = XComGameState_Ability(EventData);
    AbilityContext = XComGameStateContext_Ability(GameState.GetContext());

    if (AbilityState == none || AbilityContext == none || EffectState == none || EffectState.ApplyEffectParameters.ItemStateObjectRef != AbilityState.SourceWeapon )
    {
		`LOG("We had a problem an we are exiting listener",, 'CSSmugglerSpecWOTC --------------------------------');
        return ELR_NoInterrupt;
    }

	`LOG("Ability activated:" @ AbilityState.GetMyTemplateName(),, 'CSSmugglerSpecWOTC --------------------------------');

	if (AbilityContext.InterruptionStatus == eInterruptionStatus_Interrupt)
    {
		`LOG("At the interruption stage",, 'CSSmugglerSpecWOTC --------------------------------');
		Return ELR_NoInterrupt;
    }

	if (AbilityHasAmmoCost(AbilityState.GetMyTemplate()))
	{
		`LOG("This is not an interruption stage and the ability costs ammo.",, 'CSSmugglerSpecWOTC --------------------------------');

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState();
		WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', AbilityState.SourceWeapon.ObjectID));

		// Restore the previous ammo type
		`LOG("FlechetteRoundActivatedEventListener, old ammo:" @ WeaponState.LoadedAmmo.ObjectID @ "new ammo:" @ EffectState.GrantsThisTurn,, 'CSSmugglerSpecWOTC --------------------------------');

		WeaponState.LoadedAmmo.ObjectID = EffectState.GrantsThisTurn;			

		//`LOG("we have updated the loaded ammo to this id:" @ WeaponState.LoadedAmmo.ObjectID,, 'CSSmugglerSpecWOTC --------------------------------');
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}		
    

    return ELR_NoInterrupt;
}

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