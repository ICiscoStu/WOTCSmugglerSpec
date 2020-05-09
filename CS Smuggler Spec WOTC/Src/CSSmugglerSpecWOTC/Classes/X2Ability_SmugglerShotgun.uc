class X2Ability_SmugglerShotgun extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	Templates.AddItem(Create_Shotgun_Charge_Attack());

	return Templates;
}

static simulated function XComGameState ConcealedShotgunCharge_BuildGameState(XComGameStateContext Context)
{
    local XComGameState                NewGameState;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Unit           UnitState;
	local float                        fUnitDetectionModifier;
    
    //    Cast the Game State Context to XComGameStateContext_Ability, because this is ability activation.
    AbilityContext = XComGameStateContext_Ability(Context);    
    
    //    Prep the Unit State of the unit activating the ability for modification.
    UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AbilityContext.InputContext.SourceObject.ObjectID));
    
	fUnitDetectionModifier = UnitState.GetCurrentStat(eStat_DetectionModifier);
	UnitState.SetCurrentStat(eStat_DetectionModifier, 0);

	if (!UnitState.IsConcealed())
	{
		UnitState.SetIndividualConcealment(true, NewGameState);	
	}

    //Build the new game state frame
    NewGameState = TypicalMoveEndAbility_BuildGameState(Context);

	UnitState.SetCurrentStat(eStat_DetectionModifier, fUnitDetectionModifier);
   
    //Return the game state we have created
    return NewGameState;
}

static function X2AbilityTemplate Create_Shotgun_Charge_Attack(name TemplateName = 'CS_Shotgun_Charge_Attack')
{
	local X2AbilityTemplate						Template;
	local X2AbilityCost_Ammo					AmmoCost;
	local X2AbilityCost_QuickdrawActionPoints 	ActionPointCost;
	local X2Effect_Knockback					KnockbackEffect;

	// Add Slice Ability
	Template = class'X2Ability_RangerAbilitySet'.static.AddSwordSliceAbility(TemplateName);
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_stealth";

	// Change Hit Calc to Standard aim to count for shotgun fire and not Melee
	Template.AbilityToHitCalc = default.SimpleStandardAim;
	Template.AbilityToHitOwnerOnMissCalc = default.SimpleStandardAim;

	// Manually stop moving since shotgun has no start/stop fire animation
	Template.bSkipMoveStop = false;

	// Weapon Upgrade Compatibility
	// Flag that permits action to become 'free action' via 'Hair Trigger' or similar upgrade / effects
	Template.bAllowFreeFireWeaponUpgrade = true;                                            

	// Ammo setup
	AmmoCost = new class'X2AbilityCost_Ammo';	
	AmmoCost.iAmmo = 1;
	Template.AbilityCosts.AddItem(AmmoCost);
	Template.bAllowAmmoEffects = true;
	Template.bUseAmmoAsChargesForHUD = true;	//	Use "charges" interface to display ammo.

	// Action points setup
	ActionPointCost = new class'X2AbilityCost_QuickdrawActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	ActionPointCost.DoNotConsumeAllEffects.AddItem('SawedOffSingle_DoNotConsumeAllActionsEffect');
	Template.AbilityCosts.AddItem(ActionPointCost);	

    Template.AbilityTargetEffects.Length = 0;

    //  Put holo target effect first because if the target dies from this shot, it will be too late to notify the effect.
    Template.AddTargetEffect(class'X2Ability_GrenadierAbilitySet'.static.HoloTargetEffect());

    //  Various Soldier ability specific effects - effects check for the ability before applying  
	// Same as ApplyWeaponDamage, but also shreds target armor if the soldier has the Shredder ability  
    Template.AddTargetEffect(class'X2Ability_GrenadierAbilitySet'.static.ShredderDamageEffect());

    // Stock Compatibility - deal damage to the target on a miss if you have Stock attached to the weapon	
    Template.AddTargetEffect(default.WeaponUpgradeMissDamage);

	// Added knockback effect
	KnockbackEffect = new class'X2Effect_Knockback';
	KnockbackEffect.KnockbackDistance = 3;
	Template.AddTargetEffect(KnockbackEffect);

	Template.AbilityConfirmSound = "TacticalUI_Activate_Ability_Run_N_Gun";
	Template.ActivationSpeech = 'RunAndGun';

	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	Template.BuildNewGameStateFn = ConcealedShotgunCharge_BuildGameState;

	return Template;
}