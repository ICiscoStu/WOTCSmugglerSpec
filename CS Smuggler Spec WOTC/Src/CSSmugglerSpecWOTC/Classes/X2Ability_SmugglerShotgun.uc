class X2Ability_SmugglerShotgun extends X2Ability config(KnockBack);

var config int KNOCKBACK_TRIGGER_CHANCE;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ShotgunCharge_Stage1());
	Templates.AddItem(Create_ShotgunCharge_Stage2());

	Templates.AddItem(Create_KnockDown());
	Templates.AddItem(Create_KnockDown_Passive());

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

	//	Stage 1 is used just for targeting, so sse a custom ToHitCalc to display the "real" hit chance, but make the ability always hit in the background.
	Template.AbilityToHitCalc = new class'X2AbilityToHitCalc_ShotgunCharge';

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

}

static function bool ShotgunChargeDamagePreview(XComGameState_Ability AbilityState, StateObjectReference TargetRef, out WeaponDamageValue MinDamagePreview, out WeaponDamageValue MaxDamagePreview, out int AllowsShield)
{
	// Draft Code, I think this is working, although I think we still need the changes on RPGO for the visualization to be proper
	local XComGameState_Unit	AbilityOwner;
	local StateObjectReference	CSShotgunCharge2Ref;
	local XComGameState_Ability CSShotgunCharge2Ability;
	local XComGameStateHistory	History;

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

		`XEVENTMGR.TriggerEvent('UnitConcealmentEntered', UnitState, UnitState, NewGameState);

		//	Perform the necessary visualization
		Context.PostBuildVisualizationFn.AddItem(BuildVisualizationForConcealment_Entered_Individual);
	
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
	local XComGameStateContext_Ability	AbilityContext;
	local XComGameState_Unit			SourceUnit;
	local XComGameState_Ability			AbilityState;
	local GameRulesCache_Unit			UnitCache;
	local int i, j;

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	
	if (AbilityContext != none && AbilityContext.InterruptionStatus != eInterruptionStatus_Interrupt)
	{
		//	If Stage 1 did not include movement, then simply trigger Stage 2 against the same target.
		if (AbilityContext.InputContext.MovementPaths.Length == 0)
		{
			return AbilityState.AbilityTriggerEventListener_OriginalTarget(EventData, EventSource, GameState, EventID, CallbackData);
		}

		AbilityState = XComGameState_Ability(CallbackData);
		SourceUnit = XComGameState_Unit(GameState.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));

		if (`TACTICALRULES.GetGameRulesCache_Unit(SourceUnit.GetReference(), UnitCache))	//we get UnitCache for the soldier that triggered this ability
		{
			for (i = 0; i < UnitCache.AvailableActions.Length; i++)	//then in all actions available to him
			{
				if (UnitCache.AvailableActions[i].AbilityObjectRef.ObjectID == AbilityState.ObjectID)	//we find our ability
				{
					if (UnitCache.AvailableActions[i].AvailableCode == 'AA_Success')
					{
						for (j = 0; j < UnitCache.AvailableActions[i].AvailableTargets.Length; j++)
						{
							if (UnitCache.AvailableActions[i].AvailableTargets[j].PrimaryTarget == AbilityContext.InputContext.PrimaryTarget)
							{
								class'XComGameStateContext_Ability'.static.ActivateAbility(UnitCache.AvailableActions[i], j, /*TargetLocations*/, /*TargetingMethod*/, AbilityContext.InputContext.MovementPaths[0].MovementTiles, AbilityContext.InputContext.MovementPaths[0].WaypointTiles);
								break;
							}
						}
					}
					break;
				}
			}
		}
	}
	return ELR_NoInterrupt;
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


static function X2AbilityTemplate Create_KnockDown()
{
	local X2AbilityTemplate					Template;
	local X2AbilityTrigger_EventListener    Listener;
	local X2Effect_Knockback				KnockBackEffect;
	local X2Effect_Stunned					StunnedEffect;
	
	`CREATE_X2ABILITY_TEMPLATE(Template, 'CS_Smuggler_KnockDown');	

	//	Icon Setup
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_drop_unit"; // Placeholder icon
	SetHidden(Template);

	//	Targeting and Triggering
	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityToHitCalc = default.DeadEye;

	Listener = new class'X2AbilityTrigger_EventListener';
	Listener.ListenerData.Filter = eFilter_Unit;
	Listener.ListenerData.Deferral = ELD_OnStateSubmitted;
	Listener.ListenerData.EventFn = AbilityTriggerEventListener_KnockBack;
	Listener.ListenerData.EventID = 'AbilityActivated';
	Listener.ListenerData.Priority = 40;
	Template.AbilityTriggers.AddItem(Listener);

	//	Shooter Conditions
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);

	//	Target Conditions
	Template.AbilityTargetConditions.AddItem(default.LivingHostileTargetProperty);

	//	Ability Target Effects

	// Give the Stunned effect
	//	TODO for Iridar: Potentially changed Effect Visualization animations: CustomIdleOverrideAnim="HL_StunnedIdle", StunStartAnimName="HL_StunnedStart", StunStopAnimName="HL_StunnedStop"
	StunnedEffect = new class'X2Effect_Stunned';
	StunnedEffect.BuildPersistentEffect(1, true, true, false, eGameRule_UnitGroupTurnBegin);
	StunnedEffect.EffectName = 'CS_Stun_Effect';
	StunnedEffect.StunLevel = 1;
	StunnedEffect.bIsImpairing = true;
	StunnedEffect.EffectHierarchyValue = class'X2StatusEffects'.default.STUNNED_HIERARCHY_VALUE;
	StunnedEffect.VisualizationFn = none;
	StunnedEffect.EffectTickedVisualizationFn = class'X2StatusEffects'.static.StunnedVisualizationTicked;
	StunnedEffect.EffectRemovedVisualizationFn = class'X2StatusEffects'.static.StunnedVisualizationRemoved;
	StunnedEffect.EffectRemovedFn = class'X2StatusEffects'.static.StunnedEffectRemoved;
	StunnedEffect.bRemoveWhenTargetDies = true;
	StunnedEffect.bCanTickEveryAction = true;
	StunnedEffect.DamageTypes.AddItem('Mental');
	StunnedEffect.VFXTemplateName = class'X2StatusEffects'.default.StunnedParticle_Name;
	StunnedEffect.VFXSocket = class'X2StatusEffects'.default.StunnedSocket_Name;
	StunnedEffect.VFXSocketsArrayName = class'X2StatusEffects'.default.StunnedSocketsArray_Name;
	Template.AddTargetEffect(StunnedEffect);

	// Give the knockBack Effect
	KnockBackEffect = new class'X2Effect_Knockback';
	KnockBackEffect.KnockbackDistance = 6;
	KnockBackEffect.OverrideRagdollFinishTimerSec = 6;
	KnockBackEffect.bKnockbackDestroysNonFragile = true;
	KnockbackEffect.OnlyOnDeath = false;
	Template.AddTargetEffect(KnockBackEffect);

	//	Game States and Viz
	Template.bSkipFireAction = true;	//	Don't actually shoot the weapon the second time
	Template.bShowActivation = true;	//	Display flyover when triggering
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	//	Custom Merge Vis so that the effects applied by this ability visualize as if they 
	//	were applied by the ability that caused this one to trigger.
	Template.MergeVisualizationFn = KnockBack_MergeVisualization;

	//	Cannot be interrupted or reacted to, on purpose.
	Template.BuildInterruptGameStateFn = none;	
	Template.Hostility = eHostility_Neutral;

	Template.AdditionalAbilities.AddItem('CS_KnockDown_Passive');

	return Template;
}

static function EventListenerReturn AbilityTriggerEventListener_KnockBack(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameStateContext_Ability		AbilityContext;
	local X2Effect_ApplyWeaponDamage		DamageEffect;
	local XComGameState_Ability				AbilityState, KnockBackAbilitySate;
	local XComGameState_Unit				SourceUnit;
	local XComGameStateHistory				History;
	local X2AbilityTemplate					AbilityTemplate;
	local X2Effect							Effect;
	local XComGameStateContext				FindContext;
    local int								VisualizeIndex;
	local int								i;
	local XComGameState						NewGameState;

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());

	//	'AbilityActivated' event is triggered like this: 
	//	`XEVENTMGR.TriggerEvent('AbilityActivated', AbilityState, SourceUnitState, NewGameState);
	//	So we get AbilityState as EventData and Source Unit State as EventSource, we just need to cast them.
	//	Ability state that tiggered this event listener.
	AbilityState = XComGameState_Ability(EventData);
	SourceUnit = XComGameState_Unit(EventSource);

	//	In this case we can get the ability state from the CallbackData. When an Event Listener Fn is used as an ability trigger attached to an ability template,
	//	the Ability State of the ability with that listener will be given to the listener as CallbackData.
	KnockBackAbilitySate = XComGameState_Ability(CallbackData);
	
	if (AbilityContext != none && AbilityContext.InterruptionStatus != eInterruptionStatus_Interrupt && AbilityState != none && SourceUnit != none && KnockBackAbilitySate != none)
	{	
		AbilityTemplate = AbilityState.GetMyTemplate();

		//	Abilities that involve movement trigger the 'AbilityActivated' event every time the unit moves a tile.
		//	We don't need to trigger the Knockback ability until the triggering unit finishes their movement.
		//	So if the triggering ability involves movement
		if (AbilityContext.InputContext.MovementPaths[0].MovementTiles.Length != 0)
		{
			//	If the unit is not currently on the final tile of the movement path
			if (SourceUnit.TileLocation != AbilityContext.InputContext.MovementPaths[0].MovementTiles[AbilityContext.InputContext.MovementPaths[0].MovementTiles.Length - 1]) 
			{
				//	Exit listener.
				return ELR_NoInterrupt;
			}
		}

		//`LOG("Running Knockback listener for:" @ SourceUnit.GetFullName() @ "unit was concealed:" @ SourceUnit.WasConcealed(GameState.HistoryIndex),, 'CSSmugglerSpecWOTC');
		
		//	Check if the unit was concealed when they used the ability that triggered this listener.
		if (AbilityTemplate != none && SourceUnit.WasConcealed(GameState.HistoryIndex) && AbilityTemplate.Hostility == eHostility_Offensive && AbilityState.SourceWeapon == KnockBackAbilitySate.SourceWeapon)
		{
			//	Initial checks passed. This event listener was triggered by an offensive ability that came from the same weapon that this Ability is attached to.

			// Grant an extra action once the checks are passed regarless of the outcome of the attack
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));
			SourceUnit = XComGameState_Unit(NewGameState.ModifyStateObject(SourceUnit.Class, SourceUnit.ObjectID));
			SourceUnit.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.MoveActionPoint);
			`TACTICALRULES.SubmitGameState(NewGameState);

			History = `XCOMHISTORY;
			//	--------------------------------------------------------------------------------------
			//	## Handle Primary Target of the ability - only if the ability did not miss.
			if (AbilityContext.IsResultContextHit())
			{
				//	Cycle through all ability's target effects to check if the ability deals damage.
				foreach AbilityTemplate.AbilityTargetEffects(Effect)
				{
					DamageEffect = X2Effect_ApplyWeaponDamage(Effect);
					if (DamageEffect != none && DamageEffect.bApplyOnHit && DamageEffect.bAppliesDamage)
					{
						//	If we find at least one effect that deals damage, trigger ability if it passes a chance check
						if (`SYNC_RAND_STATIC(100) < default.KNOCKBACK_TRIGGER_CHANCE)
						{
							// Pass the Visualize Index to the Context for later use by Merge Vis Fn
							VisualizeIndex = GameState.HistoryIndex;
							FindContext = AbilityContext;
							while (FindContext.InterruptionHistoryIndex > -1)
							{
								FindContext = History.GetGameStateFromHistory(FindContext.InterruptionHistoryIndex).GetContext();
								VisualizeIndex = FindContext.AssociatedState.HistoryIndex;
							}
							KnockBackAbilitySate.AbilityTriggerAgainstSingleTarget(AbilityContext.InputContext.PrimaryTarget, false, VisualizeIndex);
						}					
						//	Stop cycling.
						break;
					}				
				}
			}
			//	--------------------------------------------------------------------------------------
			//	## Handle Multi Targets of the ability (for abilities like Faceoff and Saturation Fire)
			if (AbilityTemplate.AbilityMultiTargetStyle != none)
			{
				//	Cycle through ability's Multi Target Effects
				foreach AbilityTemplate.AbilityMultiTargetEffects(Effect)
				{
					//	If at least one ffect deals damage
					DamageEffect = X2Effect_ApplyWeaponDamage(Effect);
					if (DamageEffect != none && DamageEffect.bApplyOnHit && DamageEffect.bAppliesDamage)
					{
						//	Find visualize index if we did not already.
						if (VisualizeIndex == 0)
						{
							VisualizeIndex = GameState.HistoryIndex;
							FindContext = AbilityContext;
							while (FindContext.InterruptionHistoryIndex > -1)
							{
								FindContext = History.GetGameStateFromHistory(FindContext.InterruptionHistoryIndex).GetContext();
								VisualizeIndex = FindContext.AssociatedState.HistoryIndex;
							}
						}

						//	Cycle through all multi targets
						for (i = 0; i < AbilityContext.InputContext.MultiTargets.Length; i++)
						{		
							// Trigger the Knockback ability against each multi target, if the triggering ability did not miss that target and the target passes the chance check.
							if (AbilityContext.IsResultContextMultiHit(i) && `SYNC_RAND_STATIC(100) < default.KNOCKBACK_TRIGGER_CHANCE)
							{
								KnockBackAbilitySate.AbilityTriggerAgainstSingleTarget(AbilityContext.InputContext.MultiTargets[i], false, VisualizeIndex);	
							}
						}
					}

					//	Stop cycling
					break;
				}
			}
		}
	}
	return ELR_NoInterrupt;	
}

function KnockBack_MergeVisualization(X2Action BuildTree, out X2Action VisualizationTree)
{
	local XComGameStateVisualizationMgr		VisMgr;
	local array<X2Action>					arrActions;
	local X2Action_MarkerTreeInsertBegin	MarkerStart;
	local X2Action_MarkerTreeInsertEnd		MarkerEnd;
	local X2Action							WaitAction;
	local X2Action_MarkerNamed				MarkerAction;
	local XComGameStateContext_Ability		AbilityContext;
	local VisualizationActionMetadata		ActionMetadata;
	local bool bFoundHistoryIndex;
	local int i;

	VisMgr = `XCOMVISUALIZATIONMGR;
	
	// Find the start of the KnockBack's Vis Tree
	MarkerStart = X2Action_MarkerTreeInsertBegin(VisMgr.GetNodeOfType(BuildTree, class'X2Action_MarkerTreeInsertBegin'));
	AbilityContext = XComGameStateContext_Ability(MarkerStart.StateChangeContext);

	//	Find all Fire Actions in the Triggering Shot's Vis Tree
	VisMgr.GetNodesOfType(VisualizationTree, class'X2Action_Fire', arrActions);

	//	Cycle through all of them to find the Fire Action we need, which will have the same History Index as specified in KnockBack's Context, which gets set in the Event Listener
	for (i = 0; i < arrActions.Length; i++)
	{
		if (arrActions[i].StateChangeContext.AssociatedState.HistoryIndex == AbilityContext.DesiredVisualizationBlockIndex)
		{
			bFoundHistoryIndex = true;
			break;
		}
	}
	//	If we didn't find the correct action, we call the failsafe Merge Vis Function, which will make both KnockBack's Target Effects apply seperately after the ability finishes.
	//	Looks bad, but at least nothing is broken.
	if (!bFoundHistoryIndex)
	{
		AbilityContext.SuperMergeIntoVisualizationTree(BuildTree, VisualizationTree);
		return;
	}

	//	Add a Wait For Effect Action after the Triggering Shot's Fire Action. This will allow KnockBack's Effects to visualize the moment the Triggering Shot connects with the target.
	AbilityContext = XComGameStateContext_Ability(arrActions[i].StateChangeContext);
	ActionMetaData = arrActions[i].Metadata;
	WaitAction = class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetaData, AbilityContext,, arrActions[i]);

	//	Insert the KnockBack's Vis Tree right after the Wait For Effect Action
	VisMgr.ConnectAction(MarkerStart, VisualizationTree,, WaitAction);

	//	Main part of Merge Vis is done, now we just tidy up the ending part. As I understood from MrNice, this is necessary to make sure Vis will look fine if Fire Action ends before Singe finishes visualizing
	//	which tbh sounds like a super edge case, but okay
	//	Find all marker actions in the Triggering Shot Vis Tree.
	VisMgr.GetNodesOfType(VisualizationTree, class'X2Action_MarkerNamed', arrActions);

	//	Cycle through them and find the 'Join' Marker that comes after the Triggering Shot's Fire Action.
	for (i = 0; i < arrActions.Length; i++)
	{
		MarkerAction = X2Action_MarkerNamed(arrActions[i]);

		if (MarkerAction.MarkerName == 'Join' && MarkerAction.StateChangeContext.AssociatedState.HistoryIndex == AbilityContext.DesiredVisualizationBlockIndex)
		{
			//	Grab the last Action in the KnockBack Vis Tree
			MarkerEnd = X2Action_MarkerTreeInsertEnd(VisMgr.GetNodeOfType(BuildTree, class'X2Action_MarkerTreeInsertEnd'));

			//	TBH can't imagine circumstances where MarkerEnd wouldn't exist, but okay
			if (MarkerEnd != none)
			{
				//	"tie the shoelaces". Vis Tree won't move forward until both Knockback Vis Tree and Triggering Shot's Fire action are not fully visualized.
				VisMgr.ConnectAction(MarkerEnd, VisualizationTree,,, MarkerAction.ParentActions);
				VisMgr.ConnectAction(MarkerAction, BuildTree,, MarkerEnd);
			}
			else
			{
				//	not sure what this does
				VisMgr.GetAllLeafNodes(BuildTree, arrActions);
				VisMgr.ConnectAction(MarkerAction, BuildTree,,, arrActions);
			}
			break;
		}
	}
}

static function X2AbilityTemplate Create_KnockDown_Passive()
{
	local X2AbilityTemplate	Template;

	Template = PurePassive('CS_KnockDown_Passive', "img:///UILibrary_PerkIcons.UIPerk_drop_unit");
	return Template;
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