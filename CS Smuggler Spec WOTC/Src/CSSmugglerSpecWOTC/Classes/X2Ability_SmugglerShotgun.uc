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
	Template.BuildVisualizationFn = ShotgunCharge_Stage1_BuildVisualization;

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

static function ShotgunCharge_Stage1_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateContext_Ability AbilityContext;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyOver;
	local int ShooterID;
	local XComGameStateHistory History;
	local VisualizationActionMetadata Metadata;
	local XComGameState_Ability	AbilityState;
	local string IconImg;

	History = `XCOMHISTORY;

	// Adds concealment sound cue and display information
	AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	ShooterID = AbilityContext.InputContext.SourceObject.ObjectID;

	//	Get the Ability State so we can get Ability Template and use its Icon Image in the flyover.
	AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(AbilityContext.InputContext.AbilityRef.ObjectID));
	if (AbilityState != none)
	{
		IconImg = AbilityState.GetMyTemplate().IconImage;
	}

	//	Fill metadata for the shooter unit.
	Metadata.StateObject_OldState = History.GetGameStateForObjectID(ShooterID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	Metadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(ShooterID);
	if (Metadata.StateObject_NewState == none)
		Metadata.StateObject_NewState = Metadata.StateObject_OldState;
	Metadata.VisualizeActor = History.GetVisualizer(ShooterID);

	//	Play the sound and flyover without blocking the visualization
	SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(Metadata, AbilityContext));							
	SoundAndFlyOver.SetSoundAndFlyOverParameters(SoundCue'SoundTacticalUI.Concealment_Concealed_Cue', class'X2StatusEffects'.default.ConcealedFriendlyName, 'ActivateConcealment', eColor_Good, IconImg,, false);

	//	Unnecessary, we already call it if and when we conceal the soldier.
	//class'XComGameState_Unit'.static.BuildVisualizationForConcealmentChanged(VisualizeGameState, true);	
}

static function bool ShotgunChargeDamagePreview(XComGameState_Ability AbilityState, StateObjectReference TargetRef, out WeaponDamageValue MinDamagePreview, out WeaponDamageValue MaxDamagePreview, out int AllowsShield)
{
	// Draft Code, I think this is working, although I think we still need the changes on RPGO for the visualization to be proper
	local XComGameState_Unit	AbilityOwner;
	local StateObjectReference	CSShotgunCharge2Ref;
	local XComGameState_Ability CSShotgunCharge2Ability;
	local XComGameStateHistory	History;

	//	Unnecessary, Stage 1 ability does not apply any effects and does not deal any damage, it will have nothing to add to the damage preview.
	//AbilityState.NormalDamagePreview(TargetRef, MinDamagePreview, MaxDamagePreview, AllowsShield);

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

		//	DONE: Check if this method triggers the 'UnitConcealmentEntered' event. If not, trigger it manually here. Might be necessary for compatibility with various concealment perks.
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
	Template.BuildVisualizationFn = ShotgunCharge_Stage2_BuildVisualization;

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

static function ShotgunCharge_Stage2_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateVisualizationMgr VisualizationMgr;
	local XComGameStateContext_Ability  AbilityContext;
	local X2Action                      FoundAction;
	local X2Action_MoveTurn             MoveTurnAction;
	local XComGameState_Unit            TargetUnit;
	local XComGameStateHistory          History;
	local VisualizationActionMetadata   ActionMetadata;

	//	Generate the standard visualization for this ability. Unfortunately, it results in the soldier firing the sawed off before properly turning to the target,
	//	so we force the unit to turn by inserting a Move Turn action beween the Move End and Fire actions.
	class'X2Ability'.static.TypicalAbility_BuildVisualization(VisualizeGameState);
	
	VisualizationMgr = `XCOMVISUALIZATIONMGR;
	History = `XCOMHISTORY;
	AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	
	//	Find the Fire action for the charging soldier.
	FoundAction = VisualizationMgr.GetNodeOfType(VisualizationMgr.BuildVisTree, class'X2Action_Fire',, AbilityContext.InputContext.SourceObject.ObjectID);
	TargetUnit = XComGameState_Unit( History.GetGameStateForObjectID(AbilityContext.InputContext.PrimaryTarget.ObjectID) );
	
	if (FoundAction != none && TargetUnit != none)
	{
		ActionMetadata = FoundAction.Metadata;

		//	Insert a Move Turn action between the parents of the Fire Action and the Fire Action itself.
		MoveTurnAction = X2Action_MoveTurn(class'X2Action_MoveTurn'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, true,, FoundAction.ParentActions));
		MoveTurnAction.m_vFacePoint =  `XWORLD.GetPositionFromTileCoordinates(TargetUnit.TileLocation);
		MoveTurnAction.UpdateAimTarget = true;

		//	Unnecessary, AddToVisualizationTree will already handle all the parenting and reparenting we need.
		//VisualizationMgr.ConnectAction(FoundAction, VisualizationMgr.BuildVisTree,, MoveTurnAction);
	}
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