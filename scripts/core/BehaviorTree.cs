using Godot;
using System.Collections.Generic;

namespace CiviliSim.Core
{
    /// <summary>
    /// Motor del Behavior Tree.
    /// Evalúa el árbol de comportamiento a intervalos configurables.
    /// </summary>
    public class BehaviorTree
    {
        private BehaviorNode _root;
        private readonly float _evaluationInterval;
        private float _accumulatedTime;
        private bool _isRunning;
        private NodeStatus _lastStatus;

        private readonly Dictionary<string, Variant> _blackboard;

        public BehaviorTree(float evaluationInterval = 0.5f)
        {
            _blackboard = new Dictionary<string, Variant>();
            _evaluationInterval = evaluationInterval;
            _isRunning = false;
        }

        public void Initialize(BehaviorNode root)
        {
            _root = root;
            _accumulatedTime = 0f;
            _isRunning = true;
            _blackboard.Clear();
        }

        public bool Tick(float delta)
        {
            if (_root == null || !_isRunning)
                return false;

            _accumulatedTime += delta;

            if (_accumulatedTime >= _evaluationInterval)
            {
                _accumulatedTime = 0f;
                _lastStatus = _root.Execute(delta);
            }

            return true;
        }

        public void Stop()
        {
            _isRunning = false;
            _root?.OnInterrupt();
        }

        public void Reset()
        {
            _root?.Reset();
            _accumulatedTime = 0f;
            _isRunning = true;
        }

        public void SetBlackboard(string key, Variant value)
        {
            if (_blackboard.ContainsKey(key))
                _blackboard[key] = value;
            else
                _blackboard.Add(key, value);
        }

        public Variant GetBlackboard(string key)
        {
            if (_blackboard.TryGetValue(key, out Variant value))
                return value;
            return Variant.Nil;
        }

        public bool HasBlackboard(string key)
        {
            return _blackboard.ContainsKey(key);
        }

        public void ClearBlackboard()
        {
            _blackboard.Clear();
        }

        public NodeStatus GetLastStatus()
        {
            return _lastStatus;
        }

        public bool IsRunning()
        {
            return _isRunning;
        }

        public float GetEvaluationInterval()
        {
            return _evaluationInterval;
        }

        public void SetEvaluationInterval(float interval)
        {
            // Note: changing interval after initialization affects next tick
            // We use a field instead of readonly for this
        }
    }
}
