using Godot;
using System;

namespace CiviliSim.Core
{
    /// <summary>
    /// Builder del Behavior Tree específico para los Beeps.
    /// Construye el árbol según la arquitectura definida.
    /// </summary>
    public class BeepBehaviorBuilder
    {
        private readonly GodotObject _beepAgent;
        private readonly float _hungerThresholdWork;
        private readonly float _hungerThresholdPanic;
        private readonly float _energyThresholdRest;
        private readonly float _energyThresholdWork;
        private readonly float _healthThresholdShelter;

        public BeepBehaviorBuilder(
            GodotObject beepAgent,
            float hungerThresholdWork = 70f,
            float hungerThresholdPanic = 90f,
            float energyThresholdRest = 20f,
            float energyThresholdWork = 40f,
            float healthThresholdShelter = 30f)
        {
            _beepAgent = beepAgent;
            _hungerThresholdWork = hungerThresholdWork;
            _hungerThresholdPanic = hungerThresholdPanic;
            _energyThresholdRest = energyThresholdRest;
            _energyThresholdWork = energyThresholdWork;
            _healthThresholdShelter = healthThresholdShelter;
        }

        /// <summary>
        /// Construye el árbol de comportamiento completo del Beep.
        /// </summary>
        public BehaviorNode Build()
        {
            return new SelectorNode("RootSelector",
                BuildEmergencyEatBranch(),
                BuildRestBranch(),
                BuildSeekShelterBranch(),
                BuildColonyPriorityBranch(),
                BuildWanderBranch()
            );
        }

        /// <summary>
        /// Rama: Hambre crítica → Buscar y comer
        /// </summary>
        private BehaviorNode BuildEmergencyEatBranch()
        {
            return new SequenceNode("EmergencyEat",
                new ConditionNode("HungerPanic", (delta) =>
                {
                    return GetHunger() > _hungerThresholdPanic;
                }),
                new ActionNode("SeekFoodEmergency", (delta) =>
                {
                    _beepAgent.Call("seek_food");
                    return NodeStatus.Success;
                })
            );
        }

        /// <summary>
        /// Rama: Energía baja → Buscar refugio y descansar
        /// </summary>
        private BehaviorNode BuildRestBranch()
        {
            return new SequenceNode("Rest",
                new ConditionNode("LowEnergy", (delta) =>
                {
                    return GetEnergy() < _energyThresholdRest;
                }),
                new ActionNode("RestAction", (delta) =>
                {
                    _beepAgent.Call("rest");
                    return NodeStatus.Success;
                })
            );
        }

        /// <summary>
        /// Rama: Salud baja → Buscar refugio
        /// </summary>
        private BehaviorNode BuildSeekShelterBranch()
        {
            return new SequenceNode("SeekShelter",
                new ConditionNode("LowHealth", (delta) =>
                {
                    return GetHealth() < _healthThresholdShelter;
                }),
                new ActionNode("SeekShelterAction", (delta) =>
                {
                    _beepAgent.Call("seek_shelter");
                    return NodeStatus.Success;
                })
            );
        }

        /// <summary>
        /// Rama: Tareas según prioridad de colonia
        /// </summary>
        private BehaviorNode BuildColonyPriorityBranch()
        {
            return new SelectorNode("ColonyPriority",
                BuildFoodPriorityBranch(),
                BuildConstructionPriorityBranch(),
                BuildExplorationPriorityBranch()
            );
        }

        /// <summary>
        /// Sub-rama: Prioridad comida
        /// </summary>
        private BehaviorNode BuildFoodPriorityBranch()
        {
            return new SequenceNode("FoodPriority",
                new ConditionNode("PriorityIsFood", (delta) =>
                {
                    return GetColonyPriority() == "Comida" && GetEnergy() > _energyThresholdWork;
                }),
                new ActionNode("CollectFood", (delta) =>
                {
                    _beepAgent.Call("collect_nearby_resource");
                    return NodeStatus.Success;
                })
            );
        }

        /// <summary>
        /// Sub-rama: Prioridad construcción
        /// </summary>
        private BehaviorNode BuildConstructionPriorityBranch()
        {
            return new SequenceNode("ConstructionPriority",
                new ConditionNode("PriorityIsConstruction", (delta) =>
                {
                    return GetColonyPriority() == "Construcción" && GetEnergy() > _energyThresholdWork;
                }),
                new ActionNode("BuildAction", (delta) =>
                {
                    _beepAgent.Call("build_nearby");
                    return NodeStatus.Success;
                })
            );
        }

        /// <summary>
        /// Sub-rama: Prioridad exploración
        /// </summary>
        private BehaviorNode BuildExplorationPriorityBranch()
        {
            return new SequenceNode("ExplorationPriority",
                new ConditionNode("PriorityIsExploration", (delta) =>
                {
                    return GetColonyPriority() == "Exploración" && GetEnergy() > _energyThresholdWork * 1.5f;
                }),
                new ActionNode("ExploreAction", (delta) =>
                {
                    _beepAgent.Call("explore");
                    return NodeStatus.Success;
                })
            );
        }

        /// <summary>
        /// Rama default: Wandering aleatorio
        /// </summary>
        private BehaviorNode BuildWanderBranch()
        {
            return new ActionNode("Wander", (delta) =>
            {
                _beepAgent.Call("wander");
                return NodeStatus.Success;
            });
        }

        // --- Helpers para leer stats del Beep desde C# ---

        private float GetHunger()
        {
            return (float)(double)_beepAgent.Call("get_hunger");
        }

        private float GetEnergy()
        {
            return (float)(double)_beepAgent.Call("get_energy");
        }

        private float GetHealth()
        {
            return (float)(double)_beepAgent.Call("get_health");
        }

        private string GetColonyPriority()
        {
            return (string)_beepAgent.Call("get_colony_priority");
        }
    }
}
