using Godot;

namespace CiviliSim.Core
{
    /// <summary>
    /// Puente entre el BeepAgent (GDScript) y el Behavior Tree Engine (C#).
    /// Se adjunta como script al nodo BeepBehavior en la escena del Beep.
    /// </summary>
    public class BeepBehaviorBridge : Node
    {
        private BehaviorTree _behaviorTree;
        private Node _statsNode;
        private Node _beepAgent;

        public override void _Ready()
        {
            _beepAgent = GetParent();
            _statsNode = _beepAgent.GetNode("BeepStats");
            
            var builder = new BeepBehaviorBuilder(_beepAgent);
            var root = builder.Build();
            
            _behaviorTree = new BehaviorTree(0.5f);
            _behaviorTree.Initialize(root);
        }

        public override void _Process(float delta)
        {
            if (!IsBeepAlive())
                return;
            
            _behaviorTree?.Tick(delta);
        }

        private bool IsBeepAlive()
        {
            if (_statsNode == null) return false;
            var result = _statsNode.Call("is_alive");
            return System.Convert.ToBoolean(result);
        }
    }
}
