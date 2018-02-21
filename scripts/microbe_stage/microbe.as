// Was called everytime this object was created
// setupAbsorberForAllCompounds
#include "microbe_operations.as"


//! Why is this needed? Is it for(the future when we don't want to
//! absorb everything (or does this skip toxins, which aren't in compound registry)
void setupAbsorberForAllCompounds(CompoundAbsorberComponent@ absorber){

    uint64 compoundCount = SimulationParameters::compoundRegistry().getSize();
    for(uint a = 0; a < compoundCount; ++a){

        auto compound = SimulationParameters::compoundRegistry().getTypeData(a);
    
        absorber.setCanAbsorbCompound(compound, true);
    }
}

// Quantity of physics time between each loop distributing compounds
// to organelles. TODO: Modify to reflect microbe size.
const uint COMPOUND_PROCESS_DISTRIBUTION_INTERVAL = 100;

// Amount the microbes maxmimum bandwidth increases with per organelle
// added. This is a temporary replacement for microbe surface area
const float BANDWIDTH_PER_ORGANELLE = 1.0;

// The of time it takes for the microbe to regenerate an amount of
// bandwidth equal to maxBandwidth
const uint BANDWIDTH_REFILL_DURATION = 800;

// No idea what this does (if anything), but it isn't used in the
// process system, or when ejecting compounds.
const float STORAGE_EJECTION_THRESHHOLD = 0.8;

// The amount of time between each loop to maintaining a fill level
// below STORAGE_EJECTION_THRESHHOLD and eject useless compounds
const uint EXCESS_COMPOUND_COLLECTION_INTERVAL = 1000;

// The amount of hitpoints each organelle provides to a microbe.
const uint MICROBE_HITPOINTS_PER_ORGANELLE = 10;

// The minimum amount of oxytoxy (or any agent) needed to be able to shoot.
const float MINIMUM_AGENT_EMISSION_AMOUNT = 0.1;

// A sound effect thing for bumping with other cell i assume? Probably unused.
const float RELATIVE_VELOCITY_TO_BUMP_SOUND = 6.0;

// I think (emphasis on think) this is unused.
const float INITIAL_EMISSION_RADIUS = 0.5;

// The speed reduction when a cell is in rngulfing mode.
const uint ENGULFING_MOVEMENT_DIVISION = 3;

// The speed reduction when a cell is being engulfed.
const uint ENGULFED_MOVEMENT_DIVISION = 4;

// The amount of ATP per second spent on being on engulfing mode.
const float ENGULFING_ATP_COST_SECOND = 1.5;

// The minimum HP ratio between a cell and a possible engulfing victim.
const float ENGULF_HP_RATIO_REQ = 1.5 ;

// Cooldown between agent emissions, in milliseconds.
const uint AGENT_EMISSION_COOLDOWN = 1000;


// //! This has script only properties and operations for a Microbe entity
// //!
// //! This is held by MicrobeComponent to make sure that instances of this class don't have to
// //! be created each frame like before with lua
// //! \todo Check if it would be easier to have MicrobeComponent replace this class
// class Microbe{
    
    
// }
// Use "ObjectID microbeEntity" instead

namespace MicrobeComponent{

const string TYPE_NAME = "MicrobeComponent";
}

////////////////////////////////////////////////////////////////////////////////
// MicrobeComponent
//
// Holds data common to all microbes. You probably shouldn't use this directly,
// use MicrobeOperations instead.
////////////////////////////////////////////////////////////////////////////////
class MicrobeComponent{
    
    MicrobeComponent(ObjectID forEntity, bool isPlayerMicrobe, const string &in speciesName){
        
        this.speciesName = speciesName;
        this.isPlayerMicrobe = isPlayerMicrobe;
        this.microbeEntity = forEntity;

        // Microbe system update should initialize this component on next tick
    }

    // void load(storage){
    
    //     auto organelles = storage.get("organelles", {});
    //     for(i = 1,organelles.size()){
    //         auto organelleStorage = organelles.get(i);
    //         auto organelle = Organelle.loadOrganelle(organelleStorage);
    //         auto q = organelle.position.q;
    //         auto r = organelle.position.r;
    //         auto s = encodeAxial(q, r);
    //         this.organelles[s] = organelle;
    //     }
    //     this.hitpoints = storage.get("hitpoints", 0);
    //     this.speciesName = storage.get("speciesName", "Default");
    //     this.maxHitpoints = storage.get("maxHitpoints", 0);
    //     this.maxBandwidth = storage.get("maxBandwidth", 0);
    //     this.remainingBandwidth = storage.get("remainingBandwidth", 0);
    //     this.isPlayerMicrobe = storage.get("isPlayerMicrobe", false);
    //     this.speciesName = storage.get("speciesName", "");
        
    //     // auto compoundPriorities = storage.get("compoundPriorities", {})
    //     // for(i = 1,compoundPriorities.size()){
    //     //     auto compound = compoundPriorities.get(i)
    //     //     this.compoundPriorities[compound.get("compoundId", 0)] = compound.get("priority", 0)
    //     // }
    // }
    
    
    // void storage(storage){
    //     // Organelles
    //     auto organelles = StorageList()
    //         for(_, organelle in pairs(this.organelles)){
    //             auto organelleStorage = organelle.storage();
    //             organelles.append(organelleStorage);
    //         }
    //     storage.set("organelles", organelles);
    //     storage.set("hitpoints", this.hitpoints);
    //     storage.set("speciesName", this.speciesName);
    //     storage.set("maxHitpoints", this.maxHitpoints);
    //     storage.set("remainingBandwidth", this.remainingBandwidth);
    //     storage.set("maxBandwidth", this.maxBandwidth);
    //     storage.set("isPlayerMicrobe", this.isPlayerMicrobe);
    //     storage.set("speciesName", this.speciesName);

    //     // auto compoundPriorities = StorageList()
    //     // for(compoundId, priority in pairs(this.compoundPriorities)){
    //     //     compound = StorageContainer()
    //     //     compound.set("compoundId", compoundId)
    //     //     compound.set("priority", priority)
    //     //     compoundPriorities.append(compound)
    //     // }
    //     // storage.set("compoundPriorities", compoundPriorities)
    // }
    

    string speciesName;
    // TODO: initialize
    Float4 speciesColour;
    
    uint hitpoints;
    uint maxHitpoints = 0;
    bool dead = false;
    uint deathTimer = 0;
    array<PlacedOrganelle@> organelles;
    array<PlacedOrganelle@> specialStorageOrganelles;  // Organelles with
                                                       // complete resonsiblity
                                                       // for a specific compound
                                                       // (such as agentvacuoles)
    Float3 movementDirection = Float3(0, 0, 0);
    Float3 facingTargetPoint = Float3(0, 0, 0);
    float microbetargetdirection = 0;
    float movementFactor = 1.0; // Multiplied on the movement speed of the microbe.
    double capacity = 0;    // The amount that can be stored in the
                            // microbe. NOTE: This does not include
                            // special storage organelles.
    double stored = 0;  // The amount stored in the microbe. NOTE:
                        // This does not include special storage
                        // organelles.
    bool initialized = false;
    bool isPlayerMicrobe = false;
    float maxBandwidth = 10.0 * BANDWIDTH_PER_ORGANELLE; // wtf is a bandwidth anyway?
    float remainingBandwidth = 0.0;
    uint compoundCollectionTimer = EXCESS_COMPOUND_COLLECTION_INTERVAL;
    bool isCurrentlyEngulfing = false;
    bool isBeingEngulfed = false;
    bool wasBeingEngulfed = false;
    ObjectID hostileEngulfer = NULL_OBJECT;
    uint agentEmissionCooldown = 0;
    // Is this the place where the actual flash duration works?
    // The one in the organelle class doesn't work
    uint flashDuration = 0;
    Float4 flashColour = Float4(0, 0, 0, 0);
    uint reproductionStage = 0;


    // New state variables that MicrobeSystem also uses
    bool engulfMode = false;
    bool in_editor = false;

    // ObjectID microbe;
    ObjectID microbeEntity = NULL_OBJECT;
}

//! Helper for MicrobeSystem
class MicrobeSystemCachedComponents{

    ObjectID entity;

    CompoundAbsorberComponent@ first;
    MicrobeComponent@ second;
    RenderNode@ third;
    Physics@ fourth;
    MembraneComponent@ fifth;
    CompoundBagComponent@ sixth;
    // RigidBodyComponent ;
    // CollisionComponent ;
}



////////////////////////////////////////////////////////////////////////////////
// MicrobeSystem
//
// Updates microbes
////////////////////////////////////////////////////////////////////////////////
// TODO: This system is HUUUUUUGE! D:
// We should try to separate it into smaller systems.
// For example, the agents should be handled in another system
// (however we're going to redo agents so we should wait until then for that one)
// This is now also split into MicrobeOperations which implements all the methods that don't
// necessarily need instance data in this class (this is most things) so that they can be
// called from different places. Functions that shouldn't be called from any other place are
// kept here
class MicrobeSystem{

    // TODO: make sure these work fine after converting
        // this.microbeCollisions = CollisionFilter(
        //     "microbe",
        //     "microbe"
        // )
        // // Temporary for 0.3.2, should be moved to separate system.
        // this.agentCollisions = CollisionFilter(
        //     "microbe",
        //     "agent"
        // )

        // this.bacteriaCollisions = CollisionFilter(
        //     "microbe",
        //     "bacteria"
        // )

        // this.microbes = {}
        // }
    
    // // I don't feel like checking for each component separately, so let's make a
    // // loop do it with an assert for good measure (see Microbe.create)
    // MICROBE_COMPONENTS = {
    //     compoundAbsorber = CompoundAbsorberComponent,
    //     microbe = MicrobeComponent,
    //     rigidBody = RigidBodyComponent,
    //     sceneNode = OgreSceneNodeComponent,
    //     collisionHandler = CollisionComponent,
    //     soundSource = SoundSourceComponent,
    //     membraneComponent = MembraneComponent,
    //     compoundBag = CompoundBagComponent
    // }
    
    void Run(GameWorld@ world){
        // // Note that this triggers every frame there is a collision
        // for(_, collision in pairs(this.microbeCollisions.collisions())){
        //     auto entity1 = Entity(collision.entityId1, this.gameState.wrapper);
        //     auto entity2 = Entity(collision.entityId2, this.gameState.wrapper);
        //     if(entity1.exists() and entity2.exists()){
        //         // Engulf initiation
        //         MicrobeSystem.checkEngulfment(entity1, entity2);
        //         MicrobeSystem.checkEngulfment(entity2, entity1);
        //     }
        // }
        
        // this.microbeCollisions.clearCollisions()
        
        // // TEMP, DELETE FOR 0.3.3!!!!!!!!
        // for(_, collision in pairs(this.agentCollisions.collisions())){
        //     auto entity = Entity(collision.entityId1, this.gameState.wrapper);
        //     auto agent = Entity(collision.entityId2, this.gameState.wrapper);
            
        //     if(entity.exists() and agent.exists()){
        //         MicrobeSystem.damage(entity, .5, "toxin");
        //         agent.destroy();
        //     }
        // }
        
        // this.agentCollisions.clearCollisions()
        
        // for(_, collision in pairs(this.bacteriaCollisions.collisions())){
        //     local microbe_entity = Entity(collision.entityId1, this.gameState.wrapper);
        //     local bacterium_entity = Entity(collision.entityId2, this.gameState.wrapper);

        //     if(microbe_entity.exists() and bacterium_entity.exists()){
        //         if(world.GetComponent_Bacterium(bacterium_entity) !is null){
        //             auto bacterium = Bacterium(bacterium_entity);
        //             bacterium.damage(4);
        //         }
        //     }
        // }
        // this.bacteriaCollisions.clearCollisions();

        for(uint i = 0; i < CachedComponents.length(); ++i){
            updateMicrobe(CachedComponents[i], TICKSPEED);
        }
    }



    // Updates the microbe's state
    void updateMicrobe(MicrobeSystemCachedComponents &in components, uint logicTime){
        auto microbeEntity = components.entity;
        
        MicrobeComponent@ microbeComponent = components.second;
        MembraneComponent@ membraneComponent = components.fifth;
        RenderNode@ sceneNodeComponent = components.third;
        CompoundAbsorberComponent@ compoundAbsorberComponent = components.first;
        CompoundBagComponent@ compoundBag = components.sixth;

        if(!microbeComponent.initialized){

            LOG_INFO("Initializing microbe: " + microbeEntity);
            initializeMicrobe(microbeEntity, microbeComponent, compoundAbsorberComponent,
                compoundBag, sceneNodeComponent);
        }

        if(microbeComponent.dead){
            microbeComponent.deathTimer = microbeComponent.deathTimer - logicTime;
            microbeComponent.flashDuration = 0;
            if(microbeComponent.deathTimer <= 0){
                if(microbeComponent.isPlayerMicrobe == true){
                    MicrobeOperations::respawnPlayer(world);
                } else {

                    for(uint i = 0; i < microbeComponent.organelles.length(); ++i){
                        
                        microbeComponent.organelles[i].onRemovedFromMicrobe(microbeEntity);
                    }
                    
                    // Safe destroy before next tick
                    world.QueueDestroyEntity(microbeEntity);
                }
            }
        } else {
            // Recalculating agent cooldown time.
            microbeComponent.agentEmissionCooldown = max(
                microbeComponent.agentEmissionCooldown - logicTime, 0);

            //calculate storage.
            calculateStorageSpace(microbeEntity);

            compoundBag.storageSpace = microbeComponent.capacity;

            // StorageOrganelles
            updateCompoundAbsorber(microbeEntity);
            
            // Regenerate bandwidth
            regenerateBandwidth(microbeEntity, logicTime);
            
            // Attempt to absorb queued compounds
            auto absorbed = compoundAbsorberComponent.getAbsorbedCompounds();
            for(uint i = 0; i < absorbed.length(); ++i){
                CompoundId compound = absorbed[i];
                auto amount = compoundAbsorberComponent.absorbedCompoundAmount(compound);
                if(amount > 0.0){
                    MicrobeOperations::storeCompound(world, microbeEntity, compound,
                        amount, true);
                }
            }
            // Flash membrane if something happens.
            if(microbeComponent.flashDuration != 0 &&
                microbeComponent.flashColour != Float4(0, 0, 0, 0)
            ){
                microbeComponent.flashDuration = microbeComponent.flashDuration - logicTime;
            
                // How frequent it flashes, would be nice to update
                // the flash void to have this variable{
                
                if((microbeComponent.flashDuration % 600.0f) < 300){
                    membraneComponent.setColour(microbeComponent.flashColour);
                } else {
                    // Restore colour
                    MicrobeOperations::applyMembraneColour(world, microbeEntity);
                }

                if(microbeComponent.flashDuration <= 0){
                    microbeComponent.flashDuration = 0;
                    // Restore colour
                    MicrobeOperations::applyMembraneColour(world, microbeEntity);
                }
            }
        
            microbeComponent.compoundCollectionTimer =
                microbeComponent.compoundCollectionTimer + logicTime;
            
            while(microbeComponent.compoundCollectionTimer >
                EXCESS_COMPOUND_COLLECTION_INTERVAL)
            {
                // For every COMPOUND_DISTRIBUTION_INTERVAL passed

                microbeComponent.compoundCollectionTimer =
                    microbeComponent.compoundCollectionTimer -
                    EXCESS_COMPOUND_COLLECTION_INTERVAL;

                MicrobeOperations::purgeCompounds(world, microbeEntity);

                atpDamage(microbeEntity);
            }
        
            // First organelle run: updates all the organelles and heals the broken ones.
            if(microbeComponent.hitpoints < microbeComponent.maxHitpoints){
                for(uint i = 0; i < microbeComponent.organelles.length(); ++i){
                    
                    auto organelle = microbeComponent.organelles[i];
                    // Update the organelle.
                    organelle.update(logicTime);
                
                    // If the organelle is hurt.
                    if(organelle.getCompoundBin() < 1.0){
                        // Give the organelle access to the compound bag to take some compound.
                        organelle.growOrganelle(
                            world.GetComponent_CompoundBagComponent(microbeEntity), logicTime);
                        
                        // An organelle was damaged and we tried to
                        // heal it, so our health might be different.
                        MicrobeOperations::calculateHealthFromOrganelles(world, microbeEntity);
                    }
                }
            } else {
                auto reproductionStageComplete = true;
                array<PlacedOrganelle@> organellesToAdd;

                // Grow all the large organelles.
                for(uint i = 0; i < microbeComponent.organelles.length(); ++i){
                    
                    auto organelle = microbeComponent.organelles[i];
                    
                    // Update the organelle.
                    organelle.update(logicTime);
        
                    // We are in G1 phase of the cell cycle, duplicate all organelles.
                    if(organelle.organelle.name != "nucleus" &&
                        microbeComponent.reproductionStage == 0)
                    {
                        // If the organelle is not split, give it some
                        // compounds to make it larger.
                        if(organelle.getCompoundBin() < 2.0 && !organelle.wasSplit){
                            // Give the organelle access to the
                            // compound bag to take some compound.
                            organelle.growOrganelle(
                                world.GetComponent_CompoundBagComponent(microbeEntity),
                                logicTime);
                            
                            reproductionStageComplete = false;
                            
                            // if the organelle was split and has a
                            // bin less 1, it must have been damaged.
                        } else if(organelle.getCompoundBin() < 1.0 && organelle.wasSplit){
                            // Give the organelle access to the
                            // compound bag to take some compound.
                            organelle.growOrganelle(
                                world.GetComponent_CompoundBagComponent(microbeEntity),
                                logicTime);
                            
                            // If the organelle is twice its size...
                        } else if(organelle.getCompoundBin() >= 2.0){
                            
                            //Queue this organelle for splitting after the loop.
                            //(To avoid "cutting down the branch we're sitting on").
                            organellesToAdd.insertLast(organelle);
                        }
                        // In the S phase, the nucleus grows as chromatin is duplicated.
                    } else if (organelle.organelle.name == "nucleus" &&
                        microbeComponent.reproductionStage == 1)
                    {
                        // If the nucleus hasn't finished replicating
                        // its DNA, give it some compounds.
                        if(organelle.getCompoundBin() < 2.0){
                            // Give the organelle access to the compound
                            // back to take some compound.
                            organelle.growOrganelle(
                                world.GetComponent_CompoundBagComponent(microbeEntity),
                                logicTime);
                            reproductionStageComplete = false;
                        }
                    }
                }
                                
                //Splitting the queued organelles.
                for(uint i = 0; i < organellesToAdd.length(); ++i){
                    
                    PlacedOrganelle@ organelle = organellesToAdd[i];
                    
                    LOG_INFO("ready to split " + organelle.organelle.name);

                    // Mark this organelle as done and return to its normal size.
                    organelle.reset();
                    organelle.wasSplit = true;
                    // Create a second organelle.
                    auto organelle2 = splitOrganelle(microbeEntity, organelle);
                    organelle2.wasSplit = true;
                    organelle2.isDuplicate = true;
                    @organelle2.sisterOrganelle = organelle;
                }

                if(organellesToAdd.length() > 0){
                    // Redo the cell membrane.
                    membraneComponent.clear();
                }
            
                if(reproductionStageComplete && microbeComponent.reproductionStage < 2){
                    microbeComponent.reproductionStage += 1;
                }
                
                // To finish the G2 phase we just need more than a threshold of compounds.
                if(microbeComponent.reproductionStage == 2 ||
                    microbeComponent.reproductionStage == 3)
                {
                    readyToReproduce(microbeEntity);
                }
            }
            
            if(microbeComponent.engulfMode){
                // Drain atp and if(we run out){ disable engulfmode
                auto cost = ENGULFING_ATP_COST_SECOND/1000*logicTime;
                
                if(MicrobeOperations::takeCompound(world, microbeEntity,
                        SimulationParameters::compoundRegistry().getTypeId("atp"), cost) <
                    cost - 0.001)
                {
                    LOG_INFO("too little atp, disabling - engulfing");
                    MicrobeOperations::toggleEngulfMode(microbeEntity);
                }
                // Flash the membrane blue.
                MicrobeOperations::flashMembraneColour(world, microbeEntity, 3000,
                    Float4(0.2,0.5,1.0,0.5));
            }
            
            if(microbeComponent.isBeingEngulfed && microbeComponent.wasBeingEngulfed){
                MicrobeOperations::damage(world, microbeEntity, int(logicTime * 0.000025  *
                        microbeComponent.maxHitpoints), "isBeingEngulfed - Microbe.update()s");
                // Else If we were but are no longer, being engulfed
            } else if(microbeComponent.wasBeingEngulfed){
                removeEngulfedEffect(microbeEntity);
            }
            // Used to detect when engulfing stops
            microbeComponent.isBeingEngulfed = false;
            compoundAbsorberComponent.setAbsorbtionCapacity(min(microbeComponent.capacity -
                    microbeComponent.stored + 10, microbeComponent.remainingBandwidth));
        }
    }
    
    // Initializes microbes the first time this system processes them
    private void initializeMicrobe(ObjectID microbeEntity,
        MicrobeComponent@ microbeComponent,
        CompoundAbsorberComponent@ compoundAbsorberComponent,
        CompoundBagComponent@ compoundBag,
        RenderNode@ sceneNodeComponent
    ){
        auto rigidBodyComponent = world.GetComponent_Physics(microbeEntity);

        assert(microbeComponent.organelles.length() > 0, "Microbe has no "
            "organelles in initializeMicrobe");

        // Allowing the microbe to absorb all the compounds.
        setupAbsorberForAllCompounds(compoundAbsorberComponent);
        
        auto compoundShape = CompoundShape.castFrom(rigidBodyComponent.properties.shape);

        rigidBodyComponent.DestroyPhysicsState();
        
        
        assert(compoundShape !is null);
        compoundShape.clear();

        float mass = 0.f;

        // Organelles
        for(s, organelle in pairs(microbeComponent.organelles)){
            
            organelle.onAddedToMicrobe(microbeEntity, organelle.position.q,
                organelle.position.r, organelle.rotation);
            organelle.reset();
            
            mass += organelle.organelle.mass;
        }

        rigidBodyComponent.SetMass(mass);
                                        
        // Membrane
        sceneNodeComponent.meshName = "membrane_" + microbeComponent.speciesName;
        rigidBodyComponent.properties.touch();
        microbeComponent.initialized = true;
        
        if(microbeComponent.in_editor != true){
            assert(microbeComponent.speciesName);
                
            auto processor = world.GetComponent_speciesName(microbeComponent.speciesName,
                g_luaEngine.currentGameState,
                ProcessorComponent);
                
            if(processor is null){
                LOG_INFO("Microbe species '" + microbeComponent.speciesName +
                    "' doesn't exist");
                assert(processor);
            }
                                                
            assert(microbeComponent.speciesName != "");
            compoundBag.setProcessor(processor, microbeComponent.speciesName);
                                                
            applyTemplate(microbeEntity, MicrobeOperations::getSpeciesComponent(
                    world, microbeEntity));
        }
    }
    // ------------------------------------ //
    // Microbe operations only done by this class
    //! Updates the used storage space in a microbe and stores it in the microbe component
    void calculateStorageSpace(ObjectID microbeEntity){
        
        auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity);

        microbeComponent.stored = 0;
        uint64 compoundCount = SimulationParameters::compoundRegistry().getSize();
        for(uint a = 0; a < compoundCount; ++a){

            microbeComponent.stored += MicrobeOperations::getCompoundAmount(world,
                microbeEntity, a);
        }
    }

        
    // For updating the compound absorber
    //
    // Toggles the absorber on and off depending on the remaining storage
    // capacity of the storage organelles.
    void updateCompoundAbsorber(ObjectID microbeEntity){
        
        auto microbeComponent = (microbeEntity, MicrobeComponent);
        auto compoundAbsorberComponent = world.GetComponent_CompoundAbsorberComponent(microbeEntity,
            CompoundAbsorberComponent);

        if(//microbeComponent.stored >= microbeComponent.capacity or 
            microbeComponent.remainingBandwidth < 1 ||
            microbeComponent.dead)
        {
            compoundAbsorberComponent.disable();
        } else {
            compoundAbsorberComponent.enable();
        }
    }

    void regenerateBandwidth(ObjectID microbeEntity, int logicTime){
        auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity);
        auto addedBandwidth = microbeComponent.remainingBandwidth + logicTime *
            (microbeComponent.maxBandwidth / BANDWIDTH_REFILL_DURATION);
        microbeComponent.remainingBandwidth = min(addedBandwidth,
            microbeComponent.maxBandwidth);
    }
        

    private array<MicrobeSystemCachedComponents> CachedComponents;
    private CellStageWorld@ world;

    // Stuff that should be maybe moved out of here:
    // void checkEngulfment(ObjectID engulferMicrobeEntity, ObjectID engulfedMicrobeEntity){
    //     auto body = world.GetComponent_RigidBodyComponent(engulferMicrobeEntity, RigidBodyComponent);
    //     auto microbe1Comp = world.GetComponent_MicrobeComponent(engulferMicrobeEntity, MicrobeComponent);
    //     auto microbe2Comp = world.GetComponent_MicrobeComponent(engulfedMicrobeEntity, MicrobeComponent);
    //     auto soundSourceComponent = world.GetComponent_SoundSourceComponent(engulferMicrobeEntity, SoundSourceComponent);
    //     auto bodyEngulfed = world.GetComponent_RigidBodyComponent(engulfedMicrobeEntity, RigidBodyComponent);

    //     // That actually happens sometimes, and i think it shouldn't. :/
    //     // Probably related to a collision detection bug.
    //     // assert(body !is null, "Microbe without a rigidBody tried to engulf.")
    //     // assert(bodyEngulfed !is null, "Microbe without a rigidBody tried to be engulfed.")
    //     if(body is null || bodyEngulfed is null)
    //         return;

    //     if(microbe1Comp.engulfMode && microbe1Comp.maxHitpoints > (
    //             ENGULF_HP_RATIO_REQ * microbe2Comp.maxHitpoints) && 
    //         microbe1Comp.dead == false && microbe2Comp.dead == false)
    //     {
    //         if(!microbe1Comp.isCurrentlyEngulfing){
    //             //We have just started engulfing
    //             microbe2Comp.movementFactor = microbe2Comp.movementFactor /
    //                 ENGULFED_MOVEMENT_DIVISION;
    //             microbe1Comp.isCurrentlyEngulfing = true;
    //             microbe2Comp.wasBeingEngulfed = true;
    //             microbe2Comp.hostileEngulfer = engulferMicrobeEntity;
    //             body.disableCollisionsWith(engulfedMicrobeEntity.id);
    //             soundSourceComponent.playSound("microbe-engulfment");
    //         }

    //         //isBeingEngulfed is set to false every frame
    //         // we detect engulfment stopped by isBeingEngulfed being
    //         // false while wasBeingEngulfed is true
    //         microbe2Comp.isBeingEngulfed = true;
    //     }
    // }

    // // Attempts to obtain an amount of bandwidth for immediate use.
    // // This should be in conjunction with most operations ejecting  or absorbing compounds and agents for microbe.
    // //
    // // @param maicrobeEntity
    // // The entity of the microbe to get the bandwidth from.
    // //
    // // @param maxAmount
    // // The max amount of units that is requested.
    // //
    // // @param compoundId
    // // The compound being requested for volume considerations.
    // //
    // // @return
    // //  amount in units avaliable for use.
    // float getBandwidth(ObjectID microbeEntity, float maxAmount, CompoundId compoundId){
    //     auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity, MicrobeComponent);
    //     auto compoundVolume = CompoundRegistry.getCompoundUnitVolume(compoundId);
    //     auto amount = min(maxAmount * compoundVolume, microbeComponent.remainingBandwidth);
    //     microbeComponent.remainingBandwidth = microbeComponent.remainingBandwidth - amount;
    //     return amount / compoundVolume;
    // }


    // // Sets the color of the microbe's membrane.
    // void setMembraneColour(ObjectID microbeEntity, Float4 colour){
    //     auto membraneComponent = world.GetComponent_MembraneComponent(microbeEntity, MembraneComponent);
    //     membraneComponent.setColour(colour);
    // }






    void removeEngulfedEffect(ObjectID microbeEntity){
        auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity, MicrobeComponent);

        microbeComponent.movementFactor = microbeComponent.movementFactor *
            ENGULFED_MOVEMENT_DIVISION;
        microbeComponent.wasBeingEngulfed = false;

        auto hostileMicrobeComponent = world.GetComponent_hostileEngulfer(microbeComponent.hostileEngulfer,
            MicrobeComponent);
        if(hostileMicrobeComponent !is null){
            hostileMicrobeComponent.isCurrentlyEngulfing = false;
        }

        auto hostileRigidBodyComponent = world.GetComponent_hostileEngulfer(microbeComponent.hostileEngulfer,
            RigidBodyComponent);

        // The component is null sometimes, probably due to despawning.
        if(hostileRigidBodyComponent !is null){
            hostileRigidBodyComponent.reenableAllCollisions();
        }
        // Causes crash because sound was already stopped.
        //microbeComponent.hostileEngulfer.soundSource.stopSound("microbe-engulfment")
    }

    // // Adds a new organelle
    // //
    // // The space at (q,r) must not be occupied by another organelle already.
    // //
    // // @param q,r
    // // Offset of the organelle's center relative to the microbe's center in
    // // axial coordinates.
    // //
    // // @param organelle
    // // The organelle to add
    // //
    // // @return
    // //  returns whether the organelle was added
    // bool addOrganelle(ObjectID microbeEntity, Int2 hex, uint rotation,
    //     PlacedOrganelle@ organelle)
    // {
    //     auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity, MicrobeComponent);
    //     auto membraneComponent = world.GetComponent_MembraneComponent(microbeEntity, MembraneComponent);
    //     auto rigidBodyComponent = world.GetComponent_RigidBodyComponent(microbeEntity, RigidBodyComponent);

    //     auto s = encodeAxial(q, r);
    //     if(microbeComponent.organelles[s]){
    //         return false;
    //     }
    //     microbeComponent.organelles[s] = organelle;
    //     local x, y = axialToCartesian(q, r);
    //     auto translation = Vector3(x, y, 0);
    //     // Collision shape
    //     // TODO: cache for performance
    //     auto compoundShape = CompoundShape.castFrom(rigidBodyComponent.properties.shape);
    //     compoundShape.addChildShape(
    //         translation,
    //         Quaternion(Radian(0), Vector3(1,0,0)),
    //         organelle.collisionShape
    //     );
    //     rigidBodyComponent.properties.mass = rigidBodyComponent.properties.mass +
    //         organelle.mass;
    //     rigidBodyComponent.properties.touch();
    
    //     organelle.onAddedToMicrobe(microbeEntity, q, r, rotation);
    
    //     MicrobeSystem.calculateHealthFromOrganelles(microbeEntity);
    //     microbeComponent.maxBandwidth = microbeComponent.maxBandwidth +
    //         BANDWIDTH_PER_ORGANELLE; // Temporary solution for increasing max bandwidth
    //     microbeComponent.remainingBandwidth = microbeComponent.maxBandwidth;
    
    //     // Send the organelles to the membraneComponent so that the membrane can "grow"
    //     auto localQ = q - organelle.position.q;
    //     auto localR = r - organelle.position.r;
    //     if(organelle.getHex(localQ, localR) !is null){
    //         for(_, hex in pairs(organelle._hexes)){
    //             auto q = hex.q + organelle.position.q;
    //             auto r = hex.r + organelle.position.r;
    //             local x, y = axialToCartesian(q, r);
    //             membraneComponent.sendOrganelles(x, y);
    //         }
    //         // What is this return?
    //         return organelle;
    //     }
       
    //     return true;
    // }

    // // TODO: we have a similar method in procedural_microbes.lua and another one
    // // in microbe_editor.lua.
    // // They probably should all use the same one.
    // // We'll probably need a rotation for this, although maybe it should be done in c++ where
    // // sets are a thing?
    // bool validPlacement(ObjectID microbeEntity, Organelle organelle, Int2 hex){ 
    //     auto touching = false;
    //     for(s, hex in pairs(organelle._hexes)){
        
    //         auto organelle = MicrobeSystem.getOrganelleAt(microbeEntity, hex.q + q, hex.r + r);
    //         if(organelle){
    //             if(organelle.name != "cytoplasm"){
    //                 return false ;
    //             }
    //         }
        
    //         if(MicrobeSystem.getOrganelleAt(microbeEntity, hex.q + q + 0, hex.r + r - 1) ||
    //             MicrobeSystem.getOrganelleAt(microbeEntity, hex.q + q + 1, hex.r + r - 1) ||
    //             MicrobeSystem.getOrganelleAt(microbeEntity, hex.q + q + 1, hex.r + r + 0) ||
    //             MicrobeSystem.getOrganelleAt(microbeEntity, hex.q + q + 0, hex.r + r + 1) ||
    //             MicrobeSystem.getOrganelleAt(microbeEntity, hex.q + q - 1, hex.r + r + 1) ||
    //             MicrobeSystem.getOrganelleAt(microbeEntity, hex.q + q - 1, hex.r + r + 0))
    //         {
    //             touching = true;
    //         }
    //     }
    
    //     return touching;
    // }

    PlacedOrganelle@ splitOrganelle(ObjectID microbeEntity, PlacedOrganelle@ organelle){
        auto q = organelle.position.q;
        auto r = organelle.position.r;

        //Spiral search for space for the organelle
        auto radius = 1;
        while(true){
            //Moves into the ring of radius "radius" and center the old organelle
            q = q + HEX_NEIGHBOUR_OFFSET[HEX_SIDE.BOTTOM_LEFT][1];
            r = r + HEX_NEIGHBOUR_OFFSET[HEX_SIDE.BOTTOM_LEFT][2];

            //Iterates in the ring
            for(side = 1, 6){ //necesary due to lua not ordering the tables.
                auto offset = HEX_NEIGHBOUR_OFFSET[side];
                //Moves "radius" times into each direction
                for(i = 1, radius){
                    q = q + offset[1];
                    r = r + offset[2];

                    //Checks every possible rotation value.
                    for(j = 0, 5){
                        auto rotation = 360 * j / 6;
                        auto data = {["name"]=organelle.name, ["q"]=q, ["r"]=r,
                                     ["rotation"]=i*60};
                        auto newOrganelle = OrganelleFactory.makeOrganelle(data);

                        if(MicrobeSystem.validPlacement(microbeEntity, newOrganelle, q, r)){
                            LOG_INFO("placed " + organelle.name + " at " + q + " " + r);
                            MicrobeSystem.addOrganelle(microbeEntity, q, r, i * 60, newOrganelle);
                            return newOrganelle;
                        }
                    }
                }
            }

            radius = radius + 1;
        }
    }


    // // Kills the microbe, releasing stored compounds into the enviroment
    // void kill(ObjectID microbeEntity){
    //     auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity, MicrobeComponent);
    //     auto rigidBodyComponent = world.GetComponent_RigidBodyComponent(microbeEntity, RigidBodyComponent);
    //     auto soundSourceComponent = world.GetComponent_SoundSourceComponent(microbeEntity, SoundSourceComponent);
    //     auto microbeSceneNode = world.GetComponent_OgreSceneNodeComponent(microbeEntity, OgreSceneNodeComponent);

    //     // Hacky but meh.
    //     if(microbeComponent.dead){
    //         LOG_INFO("Trying to kill a dead microbe");
    //         return;
    //     }

    //     // Releasing all the agents.
    //     for(compoundId, _ in pairs(microbeComponent.specialStorageOrganelles)){
    //         local _amount = MicrobeSystem.getCompoundAmount(microbeEntity, compoundId);
    //         while(_amount > 0){
    //             // Eject up to 3 units per particle
    //             ejectedAmount = MicrobeSystem.takeCompound(microbeEntity, compoundId, 3); 
    //             auto direction = Vector3(math.random() * 2 - 1, math.random() * 2 - 1, 0);
    //             createAgentCloud(compoundId, microbeSceneNode.transform.position.x,
    //                 microbeSceneNode.transform.position.y, direction, amountToEject);
    //             _amount = _amount - ejectedAmount;
    //         }
    //     }
    //     auto compoundsToRelease = {};
    //     // Eject the compounds that was in the microbe
    //     for(_, compoundId in pairs(CompoundRegistry.getCompoundList())){
    //         auto total = MicrobeSystem.getCompoundAmount(microbeEntity, compoundId);
    //         auto ejectedAmount = MicrobeSystem.takeCompound(microbeEntity,
    //             compoundId, total);
    //         compoundsToRelease[compoundId] = ejectedAmount;
    //     }

    //     for(_, organelle in pairs(microbeComponent.organelles)){
    //         for(compoundName, amount in pairs(organelleTable[organelle.name].composition)){
    //             auto compoundId = CompoundRegistry.getCompoundId(compoundName);
    //             if(compoundsToRelease[compoundId] is null){
    //                 compoundsToRelease[compoundId] = amount * COMPOUND_RELEASE_PERCENTAGE;
    //             } else {
    //                 compoundsToRelease[compoundId] = compoundsToRelease[compoundId] +
    //                     amount * COMPOUND_RELEASE_PERCENTAGE;
    //             }
    //         }
    //     }

    //     // TODO: make the compounds be released inside of the microbe and not in the back.
    //     for(compoundId, amount in pairs(compoundsToRelease)){
    //         MicrobeSystem.ejectCompound(microbeEntity, compoundId, amount);
    //     }

    //     auto deathAnimationEntity = Entity(g_luaEngine.currentGameState.wrapper);
    //     auto lifeTimeComponent = TimedLifeComponent();
    //     lifeTimeComponent.timeToLive = 4000;
    //     deathAnimationEntity.addComponent(lifeTimeComponent);
    //     auto deathAnimSceneNode = OgreSceneNodeComponent();
    //     deathAnimSceneNode.meshName = "MicrobeDeath.mesh";
    //     deathAnimSceneNode.playAnimation("Death", false);
    //     deathAnimSceneNode.transform.position = Vector3(microbeSceneNode.transform.position.x,
    //         microbeSceneNode.transform.position.y, 0);
    //     deathAnimSceneNode.transform.touch();
    //     deathAnimationEntity.addComponent(deathAnimSceneNode);
    //     soundSourceComponent.playSound("microbe-death");
    //     microbeComponent.dead = true;
    //     microbeComponent.deathTimer = 5000;
    //     microbeComponent.movementDirection = Float3(0,0,0);
    //     rigidBodyComponent.clearForces();
    //     if(!microbeComponent.isPlayerMicrobe){
    //         for(_, organelle in pairs(microbeComponent.organelles)){
    //             organelle.removePhysics();
    //         }
    //     }
    //     if(microbeComponent.wasBeingEngulfed){
    //         MicrobeSystem.removeEngulfedEffect(microbeEntity);
    //     }
    //     microbeSceneNode.visible = false;
    // }



    // Damage the microbe if its too low on ATP.
    void atpDamage(ObjectID microbeEntity){
        auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity);

        if(MicrobeSystem.getCompoundAmount(microbeEntity,
                CompoundRegistry.getCompoundId("atp")) < 1.0)
        {
            // TODO: put this on a GUI notification.
            // if(microbeComponent.isPlayerMicrobe and not this.playerAlreadyShownAtpDamage){
            //     this.playerAlreadyShownAtpDamage = true
            //     showMessage("No ATP hurts you!")
            // }
            MicrobeSystem.damage(microbeEntity, EXCESS_COMPOUND_COLLECTION_INTERVAL *
                0.000002  * microbeComponent.maxHitpoints, "atpDamage") // Microbe takes 2%
                // of max hp per second in damage
        }
    }

    // // Drains an agent from the microbes special storage and emits it
    // //
    // // @param compoundId
    // // The compound id of the agent to emit
    // //
    // // @param maxAmount
    // // The maximum amount to try to emit
    // void emitAgent(ObjectID microbeEntity, CompoundId compoundId, double maxAmount){
    //     auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity, MicrobeComponent);
    //     auto sceneNodeComponent = world.GetComponent_OgreSceneNodeComponent(microbeEntity, OgreSceneNodeComponent);
    //     auto soundSourceComponent = world.GetComponent_SoundSourceComponent(microbeEntity, SoundSourceComponent);
    //     auto membraneComponent = world.GetComponent_MembraneComponent(microbeEntity, MembraneComponent);

    //     // Cooldown code
    //     if(microbeComponent.agentEmissionCooldown > 0){ return; }
    //     auto numberOfAgentVacuoles = microbeComponent.specialStorageOrganelles[compoundId];
    
    //     // Only shoot if you have agent vacuoles.
    //     if(numberOfAgentVacuoles == 0 or numberOfAgentVacuoles == 0){ return; }

    //     // The cooldown time is inversely proportional to the amount of agent vacuoles.
    //     microbeComponent.agentEmissionCooldown = AGENT_EMISSION_COOLDOWN /
    //         numberOfAgentVacuoles;

    //     if(MicrobeSystem.getCompoundAmount(microbeEntity, compoundId) >
    //         MINIMUM_AGENT_EMISSION_AMOUNT)
    //     {
    //         soundSourceComponent.playSound("microbe-release-toxin");

    //         // Calculate the emission angle of the agent emitter
    //         local organelleX, organelleY = axialToCartesian(0, -1); // The front of the microbe
    //         auto membraneCoords = membraneComponent.getExternOrganellePos(
    //             organelleX, organelleY);

    //         auto angle =  math.atan2(organelleY, organelleX);
    //         if(angle < 0){
    //             angle = angle + 2*math.pi;
    //         }
    //         angle = -(angle * 180/math.pi -90 ) % 360;

    //         // Find the direction the microbe is facing
    //         auto yAxis = sceneNodeComponent.transform.orientation.yAxis();
    //         auto microbeAngle = math.atan2(yAxis.x, yAxis.y);
    //         if(microbeAngle < 0){
    //             microbeAngle = microbeAngle + 2*math.pi;
    //         }
    //         microbeAngle = microbeAngle * 180/math.pi;
    //         // Take the microbe angle into account so we get world relative degrees
    //         auto finalAngle = (angle + microbeAngle) % 360;

    //         auto s = math.sin(finalAngle/180*math.pi);
    //         auto c = math.cos(finalAngle/180*math.pi);

    //         auto xnew = -membraneCoords[1] * c + membraneCoords[2] * s;
    //         auto ynew = membraneCoords[1] * s + membraneCoords[2] * c;
        
    //         auto direction = Vector3(xnew, ynew, 0);
    //         direction.normalise();
    //         auto amountToEject = MicrobeSystem.takeCompound(microbeEntity,
    //             compoundId, maxAmount/10.0);
    //         createAgentCloud(compoundId, sceneNodeComponent.transform.position.x + xnew,
    //             sceneNodeComponent.transform.position.y + ynew, direction,
    //             amountToEject * 10);
    //     }
    // }

    // void transferCompounds(ObjectID fromEntity, ObjectID toEntity){
    //     for(_, compoundID in pairs(CompoundRegistry.getCompoundList())){
    //         auto amount = MicrobeSystem.getCompoundAmount(fromEntity, compoundID);
    
    //         if(amount != 0){
    //             // Is it possible that compounds are created or destroyed here as
    //             // the actual amounts aren't checked (that these functions should return)
    //             MicrobeSystem.takeCompound(fromEntity, compoundID, amount, false);
    //             MicrobeSystem.storeCompound(toEntity, compoundID, amount, false);
    //         }
    //     }
    // }

    // // Creates a new microbe with all required components
    // //
    // // @param name
    // // The entity's name. If null, the entity will be unnamed.
    // //
    // // @returns microbe
    // // An object of type Microbe
    // ObjectID createMicrobeEntity(const string &in name, bool aiControlled,
    //     const string &in speciesName, bool in_editor)
    // {
    //     assert(speciesName != "", "Empty species name for create microbe");

    //     local entity;
    //     if(name){
    //         entity = Entity(name, g_luaEngine.currentGameState.wrapper);
    //     } else {
    //         entity = Entity(g_luaEngine.currentGameState.wrapper);
    //     }

    //     auto rigidBody = RigidBodyComponent();
    //     rigidBody.properties.shape = CompoundShape();
    //     rigidBody.properties.linearDamping = 0.5;
    //     rigidBody.properties.friction = 0.2;
    //     rigidBody.properties.mass = 0.0;
    //     rigidBody.properties.linearFactor = Vector3(1, 1, 0);
    //     rigidBody.properties.angularFactor = Vector3(0, 0, 1);
    //     rigidBody.properties.touch();

    //     auto reactionHandler = CollisionComponent();
    //     reactionHandler.addCollisionGroup("microbe");

    //     auto membraneComponent = MembraneComponent();

    //     auto soundComponent = SoundSourceComponent();
    //     auto s1 = null;
    //     soundComponent.addSound("microbe-release-toxin",
    //         "soundeffects/microbe-release-toxin.ogg");
    //     soundComponent.addSound("microbe-toxin-damage",
    //         "soundeffects/microbe-toxin-damage.ogg");
    //     soundComponent.addSound("microbe-death", "soundeffects/microbe-death.ogg");
    //     soundComponent.addSound("microbe-pickup-organelle",
    //         "soundeffects/microbe-pickup-organelle.ogg");
    //     soundComponent.addSound("microbe-engulfment", "soundeffects/engulfment.ogg");
    //     soundComponent.addSound("microbe-reproduction", "soundeffects/reproduction.ogg");

    //     s1 = soundComponent.addSound("microbe-movement-1",
    //         "soundeffects/microbe-movement-1.ogg");
    //     s1.properties.volume = 0.4;
    //     s1.properties.touch();
    //     s1 = soundComponent.addSound("microbe-movement-turn",
    //         "soundeffects/microbe-movement-2.ogg");
    //     s1.properties.volume = 0.1;
    //     s1.properties.touch();
    //     s1 = soundComponent.addSound("microbe-movement-2",
    //         "soundeffects/microbe-movement-3.ogg");
    //     s1.properties.volume = 0.4;
    //     s1.properties.touch();

    //     auto components = {
    //         CompoundAbsorberComponent(),
    //         OgreSceneNodeComponent(),
    //         CompoundBagComponent(),
    //         MicrobeComponent(not aiControlled, speciesName),
    //         reactionHandler,
    //         rigidBody,
    //         soundComponent,
    //         membraneComponent
    //     }

    //     if(aiControlled){
    //         auto aiController = MicrobeAIControllerComponent();
    //         table.insert(components, aiController);
    //     }

    //     for(_, component in ipairs(components)){
    //         entity.addComponent(component);
    //     }
    
    //     MicrobeSystem.initializeMicrobe(entity, in_editor, g_luaEngine.currentGameState);

    //     return entity;
    // }

    // void divide(ObjectID microbeEntity){
    //     auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity, MicrobeComponent);
    //     auto soundSourceComponent = world.GetComponent_SoundSourceComponent(microbeEntity, SoundSourceComponent);
    //     auto membraneComponent = world.GetComponent_MembraneComponent(microbeEntity, MembraneComponent);
    //     auto rigidBodyComponent = world.GetComponent_RigidBodyComponent(microbeEntity, RigidBodyComponent);

    //     // Create the two daughter cells.
    //     auto copyEntity = MicrobeSystem.createMicrobeEntity(null, true,
    //         microbeComponent.speciesName, false);
    //     auto microbeComponentCopy = world.GetComponent_MicrobeComponent(copyEntity, MicrobeComponent);
    //     auto rigidBodyComponentCopy = world.GetComponent_RigidBodyComponent(copyEntity, RigidBodyComponent);

    //     //Separate the two cells.
    //     rigidBodyComponentCopy.dynamicProperties.position = Vector3(
    //         rigidBodyComponent.dynamicProperties.position.x - membraneComponent.dimensions/2,
    //         rigidBodyComponent.dynamicProperties.position.y, 0);
    //     rigidBodyComponent.dynamicProperties.position = Vector3(
    //         rigidBodyComponent.dynamicProperties.position.x + membraneComponent.dimensions/2,
    //         rigidBodyComponent.dynamicProperties.position.y, 0);

    //     // Split the compounds evenly between the two cells.
    //     for(_, compoundID in pairs(CompoundRegistry.getCompoundList())){
    //         auto amount = MicrobeSystem.getCompoundAmount(microbeEntity, compoundID);

    //         if(amount != 0){
    //             MicrobeSystem.takeCompound(microbeEntity, compoundID, amount / 2, false);
    //             MicrobeSystem.storeCompound(copyEntity, compoundID, amount / 2, false);
    //         }
    //     }
    
    //     microbeComponent.reproductionStage = 0;
    //     microbeComponentCopy.reproductionStage = 0;

    //     auto spawnedComponent = SpawnedComponent();
    //     spawnedComponent.setSpawnRadius(MICROBE_SPAWN_RADIUS);
    //     copyEntity.addComponent(spawnedComponent);
    //     soundSourceComponent.playSound("microbe-reproduction");
    // }

    // Copies this microbe. The new microbe will not have the stored compounds of this one.
    void readyToReproduce(ObjectID microbeEntity){
        auto microbeComponent = world.GetComponent_MicrobeComponent(microbeEntity);

        if(microbeComponent.isPlayerMicrobe){
            showReproductionDialog();
            microbeComponent.reproductionStage = 0;
        else
            // Return the first cell to its normal, non duplicated cell arangement.
            applyTemplate(microbeEntity,
                MicrobeOperations::getSpeciesComponent(world, microbeEntity));
            
            MicrobeSystem.divide(microbeEntity);
        }
    }

    // This is defined in the lua scripts in some weird place
    void applyTemplate(ObjectID microbe, SpeciesComponent@ species){

        assert(false, "TODO: find where this is the lua scripts and put it here");
    }
    
}