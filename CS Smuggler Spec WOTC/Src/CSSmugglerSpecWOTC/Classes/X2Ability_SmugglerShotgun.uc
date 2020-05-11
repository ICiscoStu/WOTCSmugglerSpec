class X2Ability_SmugglerShotgun extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ShotgunCharge_Stage1());
	Templates.AddItem(Create_ShotgunCharge_Stage2());

	return Templates;
}

//	Stage 1: Select target enemy as if you're gonna attack them in melee. Conceals the soldier, records their current Detection Modifier stat as a Unit Value and triggers the event.
//	Stage 2: Get activated by the event, perform a running melee attack against the target selected on Stage 1, retrieve the Detection Modifier from the Unit Value and restore it for the unit.

static function X2AbilityTemplate Create_ShotgunCharge_Stage1(name TemplateName = 'CS_ShotgunCharge_Stage1')
{
	local X2AbilityTemplate						Template;
	local X2AbilityCost_Ammo					AmmoCost;
	local X2AbilityCost_QuickdrawActionPoints 	ActionPointCost;

	Template = class'X2Ability_RangerAbilitySet'.static.AddSwordSliceAbility(TemplateName);

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_stealth";

	//	Stage 1 is used just for targeting, so it's guaranteed to hit.
	//	TODO: Make this ability display its hit chance properly in the targeting preview.
	//	Might require a custom To Hit Calc.
	//	Essentially we need *this* ability to always hit, but display in the preview the chance to hit from another ability.
	Template.AbilityToHitCalc = default.DeadEye;

	//Template.AbilityTargetStyle = default.SimpleSingleTarget;
	//Template.TargetingMethod = class'X2TargetingMethod_MeleePath';

	//	Remove ability costs and replace them with ours
	//	Set them as Free Costs here; they will be actually applied by Stage 2 ability.
	Template.AbilityCosts.Length = 0;

	// Action points setup
	ActionPointCost = new class'X2AbilityCost_QuickdrawActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	ActionPointCost.DoNotConsumeAllEffects.AddItem('SawedOffSingle_DoNotConsumeAllActionsEffect');
	ActionPointCost.bFreeCost = true;
	Template.AbilityCosts.AddItem(ActionPointCost);	

	// Require one ammo to be present
	AmmoCost = new class'X2AbilityCost_Ammo';	
	AmmoCost.iAmmo = 1;
	AmmoCost.bFreeCost = true;
	Template.AbilityCosts.AddItem(AmmoCost);
	Template.bUseAmmoAsChargesForHUD = true;	//	Use "charges" interface to display ammo.

	//	Remove all effects from this ability. 
	//	We do what we need to do in the Build Game State Function.
	Template.AbilityTargetEffects.Length = 0;
	
	//	Removed to avoid clashing "Entering concealment" speech.
	RemoveVoiceLines(Template);
	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	//	Activating this ability does not break concealment
	Template.ConcealmentRule = eConceal_AlwaysEvenWithObjective;
	
	Template.BuildNewGameStateFn = ShotgunCharge_Stage1_BuildGameState;
	Template.BuildInterruptGameStateFn = none;	//	This ability cannot be interrupted.
	Template.BuildVisualizationFn = none;		//	No visualization on purpose. This prevents the soldier from moving when activating this ability.

	//	This sound effect will be played by the UI.
	//Template.AbilityConfirmSound = "TacticalUI_ActivateAbility";
	Template.AbilityConfirmSound = "TacticalUI_Activate_Ability_Run_N_Gun";

	//	Removing speech lines from this ability is not necessary, since those are played by Build Visualization function, which we don't have.

	//	Activating this ability does not provoke enemy reactions
	Template.Hostility = eHostility_Neutral;
	Template.SuperConcealmentLoss = 0;
	Template.ChosenActivationIncreasePerUse = 0;
	Template.LostSpawnIncreasePerUse = 0;

		//	Attach an additional ability by Template Name. 
	Template.AdditionalAbilities.AddItem('CS_ShotgunCharge_Stage2');
	Template.PostActivationEvents.AddItem('CS_ShotgunCharge_Stage1_Event');

	Template.DamagePreviewFn = ShotgunChargeDamagePreview;

	return Template;
}

static function bool ShotgunChargeDamagePreview(XComGameState_Ability AbilityState, StateObjectReference TargetRef, out WeaponDamageValue MinDamagePreview, out WeaponDamageValue MaxDamagePreview, out int AllowsShield)
{
	//	TODO: Add proper damage preview to Stage 1. Should do this by grabbing Stage 2 Ability State from the unit and getting its damage preview. 

	// Draft Code
	local XComGameState_Unit AbilityOwner;
	local StateObjectReference CSShotgunCharge2Ref;
	local XComGameState_Ability CSShotgunCharge2Ability;
	local XComGameStateHistory History;

	AbilityState.NormalDamagePreview(TargetRef, MinDamagePreview, MaxDamagePreview, AllowsShield);

	History = `XCOMHISTORY;
	AbilityOwner = XComGameState_Unit(History.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
	CSShotgunCharge2Ref = AbilityOwner.FindAbility('CS_ShotgunCharge_Stage2');
	CSShotgunCharge2Ability = XComGameState_Ability(History.GetGameStateForObjectID(CSShotgunCharge2Ref.ObjectID));
	if (CSShotgunCharge2Ability == none)
	{
		`LOG("Unit has ChargeShot but is missing ChargeShot2. Not good." );
	}
	else
	{
		CSShotgunCharge2Ability.NormalDamagePreview(TargetRef, MinDamagePreview, MaxDamagePreview, AllowsShield);
	}
	return true;

}

static simulated function XComGameState ShotgunCharge_Stage1_BuildGameState(XComGameStateContext Context)
{
    local XComGameState					NewGameState;
	local XComGameStateContext_Ability	AbilityContext;
    local XComGameState_Unit			UnitState;
	local float							fUnitDetectionModifier;
    
    //	Cast the Game State Context to XComGameStateContext_Ability, because this is ability activation.
    AbilityContext = XComGameStateContext_Ability(Context);    

	//	Create a new Game State
	NewGameState = `XCOMHISTORY.CreateNewGameState(true, Context);

	//	Prep the Unit State for modification.
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AbilityContext.InputContext.SourceObject.ObjectID));

	//	Record the unit's current detection modifier in a Unit Value. Do it before actually concealing the unit 
	//	in case the unit might lose concealment due to being detected before we can modify the detection modifier.
	fUnitDetectionModifier = UnitState.GetCurrentStat(eStat_DetectionModifier);

	`LOG("Shotgun Charge Stage 1: recording detection modifier for unit:" @ UnitState.GetFullName() @ "as" @ fUnitDetectionModifier,, 'CSSmugglerSpecWOTC');
	UnitState.SetUnitFloatValue('CS_ShotgunCharge_DetectionModifier_Value', fUnitDetectionModifier, eCleanup_BeginTurn);

	//	And set it to 1 to make the soldier undetectable.
	UnitState.SetBaseMaxStat(eStat_DetectionModifier, 1);
    
	//	Conceal the unit, if not concealed already.
    if (!UnitState.IsConcealed())
    {
		//	Conceal the unit
		UnitState.SetIndividualConcealment(true, NewGameState);

		//	TODO: Check if this method triggers the 'UnitConcealmentEntered' event. If not, trigger it manually here. Might be necessary for compatibility with various concealment perks.
		// Draft code
		`XEVENTMGR.TriggerEvent('UnitConcealmentEntered', UnitState, UnitState, NewGameState);

		//	Perform the necessary visualization
		Context.PostBuildVisualizationFn.AddItem(BuildVisualizationForConcealment_Entered_Individual);
	
		//	Should not do activate concealment through this Event, since the function ran by this event submits a new game state, and we already have one created.
		//`XEVENTMGR.TriggerEvent('EffectEnterUnitConcealment', UnitState, UnitState, NewGameState);
    }
   
    //Return the game state we have created
    return NewGameState;
}

private function BuildVisualizationForConcealment_Entered_Individual(XComGameState VisualizeGameState)
{	
	//	TODO: Would be nice to play "get into concealment" sound effect when Stage 1 is activated, the same one you hear at the start of the mission.

	// Draft code this is what I tried but it did not work
	// local XComGameStateHistory         History;
	// local XComGameStateContext_Ability AbilityContext;
	// local XComGameState_Ability        Ability;
	// local VisualizationActionMetadata  ActionMetadata;
	// local VisualizationActionMetadata  EmptyTrack;

	// History = `XCOMHISTORY;
	// AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	// Ability = XComGameState_Ability(History.GetGameStateForObjectID(AbilityContext.InputContext.AbilityRef.ObjectID));
	// ActionMetadata = EmptyTrack;

	// class'X2StatusEffects'.static.AddEffectSoundAndFlyOverToTrack(ActionMetadata, VisualizeGameState.GetContext(), class'X2StatusEffects'.default.BleedingOutFriendlyName, 'Poison', eColor_Bad, class'UIUtilities_Image'.const.UnitStatus_Poisoned);
	// Ability.GetMyTemplate().ActivationSpeech = 'ActivateConcealment';

	//	TODO: Fully rotate the soldier's pawn to face the target before beginning the fire action.

	class'XComGameState_Unit'.static.BuildVisualizationForConcealmentChanged(VisualizeGameState, true);	
}

static function X2AbilityTemplate Create_ShotgunCharge_Stage2(name TemplateName = 'CS_ShotgunCharge_Stage2')
{
	local X2AbilityTemplate						Template;
	local X2AbilityCost_Ammo					AmmoCost;
	local X2AbilityCost_QuickdrawActionPoints 	ActionPointCost;
	local X2AbilityTrigger_EventListener        Trigger;

	//	This function is called when the template is created when the game is launched, not when ability code is executed.
	//	`LOG("Entering Second charge Attack");

	Template = class'X2Ability_RangerAbilitySet'.static.AddSwordSliceAbility(TemplateName);

	//	Use standard hit calc instead of melee one.
	//	TODO: Make this ability's hit chance unaffected by Sawed Off's range penalties. 
	//	Or, rather, they need to affect this ability *after* the soldier has closed the distance.
	//	Might require a custom ToHitCalc, though it's easier to address this on the side of the RPGO.
	//	The RPGO logic that handles reducing hit chance by distance needs to check if the ability whose damage is beind modified has
	//	"X2AbilityTarget_MovingMelee(Template.AbilityTargetStyle) != none" or "Template.TargetingMethod == class'X2TargetingMethod_MeleePath'", 
	//	and in that case return damage / hit chance modifiers as if the soldier is on the neighboring tile to the enemy.
	Template.AbilityToHitCalc = default.SimpleStandardAim;

	//	Hide the ability from UI
	SetHidden(Template);

	//	Remove ability costs and replace them with ours.
	Template.AbilityCosts.Length = 0;

	// Action points setup
	ActionPointCost = new class'X2AbilityCost_QuickdrawActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	ActionPointCost.DoNotConsumeAllEffects.AddItem('SawedOffSingle_DoNotConsumeAllActionsEffect');
	Template.AbilityCosts.AddItem(ActionPointCost);	

	// Require one ammo to be present
	AmmoCost = new class'X2AbilityCost_Ammo';	
	AmmoCost.iAmmo = 1;
	Template.AbilityCosts.AddItem(AmmoCost);

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_stealth";

	//	Replace weapon damage effect from AddSwordSlice by ours.
	Template.AbilityTargetEffects.Length = 0;
	 // Put holo target effect first because if the target dies from this shot, it will be too late to notify the effect.
    Template.AddTargetEffect(class'X2Ability_GrenadierAbilitySet'.static.HoloTargetEffect());

	// Same as ApplyWeaponDamage, but also shreds target armor if the soldier has the Shredder ability.
	//	TODO: Make it so this ability's damage is not affected by RPGO's "reduce damage at range" logic. See above for more details.
    Template.AddTargetEffect(class'X2Ability_GrenadierAbilitySet'.static.ShredderDamageEffect());

    Template.AddTargetEffect(default.WeaponUpgradeMissDamage);	// Stock Compatibility - deal damage to the target on a miss if you have Stock attached to the weapon	
	Template.bAllowAmmoEffects = true;							// Utility Slot Ammo items compatibility.
	Template.bAllowFreeFireWeaponUpgrade = true;				// Hair Trigger compatibility

	//	Replace ability trigger with the Event Listener
	Template.AbilityTriggers.Length = 0;

	Trigger = new class'X2AbilityTrigger_EventListener';
	Trigger.ListenerData.Deferral = ELD_OnStateSubmitted;
	Trigger.ListenerData.EventID = 'CS_ShotgunCharge_Stage1_Event';
	Trigger.ListenerData.Filter = eFilter_Unit;	//	Unit Filter on the event trigger listener will make this listener listen only to events triggered by this unit.
	Trigger.ListenerData.EventFn = AbilityTriggerEventListener_ShotgunCharge;	//	This is the function that will run when the event is triggered.
	Template.AbilityTriggers.AddItem(Trigger);

	// Manually stop moving since shotgun has no start/stop fire animation
	Template.bSkipMoveStop = false;
	Template.BuildNewGameStateFn = ShotgunCharge_Stage2_BuildGameState;

	//	Remove speech line.
	Template.ActivationSpeech = '';
	Template.AbilityConfirmSound = "";

	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	return Template;
}

static function EventListenerReturn AbilityTriggerEventListener_ShotgunCharge(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_Ability	AbilityState;
	
	AbilityState = XComGameState_Ability(CallbackData);

	`LOG("Running event trigger listener for ability:" @ AbilityState.GetMyTemplateName(),, 'CSSmugglerSpecWOTC');
	//	TODO for Iridar: Add custom logic that would make Stage 2 ability move the soldier to the specific tile selected by the player during Stage 1.

	return AbilityState.AbilityTriggerEventListener_OriginalTarget(EventData, EventSource, GameState, EventID, CallbackData);
}

static simulated function XComGameState ShotgunCharge_Stage2_BuildGameState(XComGameStateContext Context)
{
	local XComGameState					NewGameState;
	local UnitValue						UV;
	local XComGameStateContext_Ability	AbilityContext;
    local XComGameState_Unit			UnitState;

	NewGameState = `XCOMHISTORY.CreateNewGameState(true, Context);

	//	Perform the regular ability activation actions.
	class'X2Ability_DefaultAbilitySet'.static.MoveAbility_FillOutGameState(NewGameState, false); //Do not apply costs at this time.
	TypicalAbility_FillOutGameState(NewGameState); //Costs applied here.

	AbilityContext = XComGameStateContext_Ability(Context);    
	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));
	
	if (UnitState.GetUnitValue('CS_ShotgunCharge_DetectionModifier_Value', UV))
	{
		`LOG("Shotgun Charge Stage 2: restoring detection modifier for unit:" @ UnitState.GetFullName() @ "from:" @ UnitState.GetCurrentStat(eStat_DetectionModifier) @ "to" @ UV.fValue,, 'CSSmugglerSpecWOTC');
		UnitState.SetBaseMaxStat(eStat_DetectionModifier, UV.fValue);
	}
	else `LOG("ERROR, could not get shotgun charge detection modifier Unit Value for unit:" @ UnitState.GetFullName(),, 'CSSmugglerSpecWOTC');

	return NewGameState;
}


//	========================================
//				HELPER FUNCTIONS
//	========================================

static function RemoveVoiceLines(out X2AbilityTemplate Template)
{
	Template.ActivationSpeech = '';
	Template.SourceHitSpeech = '';
	Template.TargetHitSpeech = '';
	Template.SourceMissSpeech = '';
	Template.TargetMissSpeech = '';
	Template.TargetKilledByAlienSpeech = '';
	Template.TargetKilledByXComSpeech = '';
	Template.MultiTargetsKilledByAlienSpeech = '';
	Template.MultiTargetsKilledByXComSpeech = '';
	Template.TargetWingedSpeech = '';
	Template.TargetArmorHitSpeech = '';
	Template.TargetMissedSpeech = '';
}

static function SetHidden(out X2AbilityTemplate Template)
{
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bDisplayInUITacticalText = false;
	Template.bDisplayInUITooltip = false;
	Template.bDontDisplayInAbilitySummary = true;
	Template.bHideOnClassUnlock = true;
}