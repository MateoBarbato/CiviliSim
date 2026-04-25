using Godot;

namespace CiviliSim.Core
{
    /// <summary>
    /// Estado de ejecución de un nodo en el Behavior Tree
    /// </summary>
    public enum NodeStatus
    {
        Success,
        Failure,
        Running
    }

    /// <summary>
    /// Nodo base para el Behavior Tree.
    /// Todos los nodos del árbol heredan de esta clase.
    /// </summary>
    public abstract class BehaviorNode
    {
        public string Name { get; protected set; }
        public BehaviorNode Parent { get; protected set; }

        public BehaviorNode(string name)
        {
            Name = name;
        }

        /// <summary>
        /// Ejecuta el nodo. Debe ser implementado por cada tipo de nodo.
        /// </summary>
        public abstract NodeStatus Execute(float delta);

        /// <summary>
        /// Limpia el estado del nodo cuando se deja de ejecutar.
        /// </summary>
        public virtual void OnInterrupt()
        {
        }

        /// <summary>
        /// Resetea el estado del nodo para una nueva ejecución.
        /// </summary>
        public virtual void Reset()
        {
        }
    }

    /// <summary>
    /// Nodo de acción: ejecuta una tarea específica.
    /// Es el nodo hoja del árbol.
    /// </summary>
    public class ActionNode : BehaviorNode
    {
        private System.Action<float> _action;
        private System.Func<float, NodeStatus> _execute;
        private System.Action _onInterrupt;
        private System.Action _onReset;

        public ActionNode(string name, System.Func<float, NodeStatus> execute)
            : base(name)
        {
            _execute = execute;
        }

        public override NodeStatus Execute(float delta)
        {
            return _execute?.Invoke(delta) ?? NodeStatus.Failure;
        }

        public void SetOnInterrupt(System.Action callback)
        {
            _onInterrupt = callback;
        }

        public void SetOnReset(System.Action callback)
        {
            _onReset = callback;
        }

        public override void OnInterrupt()
        {
            _onInterrupt?.Invoke();
        }

        public override void Reset()
        {
            _onReset?.Invoke();
        }
    }

    /// <summary>
    /// Nodo de condición: evalúa una condición sin efecto secundario.
    /// </summary>
    public class ConditionNode : BehaviorNode
    {
        private System.Func<float, bool> _condition;

        public ConditionNode(string name, System.Func<float, bool> condition)
            : base(name)
        {
            _condition = condition;
        }

        public override NodeStatus Execute(float delta)
        {
            return _condition?.Invoke(delta) == true ? NodeStatus.Success : NodeStatus.Failure;
        }
    }

    /// <summary>
    /// Selector: ejecuta sus hijos en orden hasta que uno tenga éxito.
    /// Retorna Failure si todos fallan.
    /// </summary>
    public class SelectorNode : BehaviorNode
    {
        private readonly BehaviorNode[] _children;
        private int _currentIndex = 0;

        public SelectorNode(string name, params BehaviorNode[] children)
            : base(name)
        {
            _children = children;
            foreach (var child in children)
            {
                child.Parent = this;
            }
        }

        public override NodeStatus Execute(float delta)
        {
            for (; _currentIndex < _children.Length; _currentIndex++)
            {
                var status = _children[_currentIndex].Execute(delta);
                switch (status)
                {
                    case NodeStatus.Success:
                        _currentIndex = 0;
                        return NodeStatus.Success;
                    case NodeStatus.Failure:
                        break;
                    case NodeStatus.Running:
                        return NodeStatus.Running;
                }
            }
            _currentIndex = 0;
            return NodeStatus.Failure;
        }

        public override void Reset()
        {
            _currentIndex = 0;
            foreach (var child in _children)
            {
                child.Reset();
            }
        }

        public override void OnInterrupt()
        {
            _children[_currentIndex]?.OnInterrupt();
        }
    }

    /// <summary>
    /// Sequence: ejecuta sus hijos en orden. Todos deben tener éxito.
    /// Si uno falla, la secuencia falla.
    /// </summary>
    public class SequenceNode : BehaviorNode
    {
        private readonly BehaviorNode[] _children;
        private int _currentIndex = 0;

        public SequenceNode(string name, params BehaviorNode[] children)
            : base(name)
        {
            _children = children;
            foreach (var child in children)
            {
                child.Parent = this;
            }
        }

        public override NodeStatus Execute(float delta)
        {
            for (; _currentIndex < _children.Length; _currentIndex++)
            {
                var status = _children[_currentIndex].Execute(delta);
                switch (status)
                {
                    case NodeStatus.Success:
                        break;
                    case NodeStatus.Failure:
                        _currentIndex = 0;
                        foreach (var child in _children)
                        {
                            child.Reset();
                        }
                        return NodeStatus.Failure;
                    case NodeStatus.Running:
                        return NodeStatus.Running;
                }
            }
            _currentIndex = 0;
            return NodeStatus.Success;
        }

        public override void Reset()
        {
            _currentIndex = 0;
            foreach (var child in _children)
            {
                child.Reset();
            }
        }

        public override void OnInterrupt()
        {
            _children[_currentIndex]?.OnInterrupt();
        }
    }

    /// <summary>
    /// Parallel: ejecuta múltiples hijos en paralelo.
    /// Retorna Success cuando la cantidad de éxitos alcanza el umbral.
    /// </summary>
    public class ParallelNode : BehaviorNode
    {
        private readonly BehaviorNode[] _children;
        private readonly int _successThreshold;
        private readonly NodeStatus[] _childStates;

        public ParallelNode(string name, int successThreshold, params BehaviorNode[] children)
            : base(name)
        {
            _children = children;
            _successThreshold = successThreshold;
            _childStates = new NodeStatus[_children.Length];
            for (int i = 0; i < _childStates.Length; i++)
            {
                _childStates[i] = NodeStatus.Running;
            }
            foreach (var child in children)
            {
                child.Parent = this;
            }
        }

        public override NodeStatus Execute(float delta)
        {
            int successCount = 0;
            bool anyRunning = false;

            for (int i = 0; i < _children.Length; i++)
            {
                if (_childStates[i] == NodeStatus.Running)
                {
                    var status = _children[i].Execute(delta);
                    _childStates[i] = status;

                    switch (status)
                    {
                        case NodeStatus.Success:
                            successCount++;
                            break;
                        case NodeStatus.Running:
                            anyRunning = true;
                            break;
                    }
                }
                else if (_childStates[i] == NodeStatus.Success)
                {
                    successCount++;
                }
            }

            if (successCount >= _successThreshold)
            {
                return NodeStatus.Success;
            }

            return anyRunning ? NodeStatus.Running : NodeStatus.Failure;
        }

        public override void Reset()
        {
            for (int i = 0; i < _childStates.Length; i++)
            {
                _childStates[i] = NodeStatus.Running;
            }
            foreach (var child in _children)
            {
                child.Reset();
            }
        }
    }

    /// <summary>
    /// Repeater: ejecuta un hijo un número determinado de veces.
    /// </summary>
    public class RepeaterNode : BehaviorNode
    {
        private readonly BehaviorNode _child;
        private readonly int _maxIterations;
        private int _currentIteration = 0;

        public RepeaterNode(string name, int maxIterations, BehaviorNode child)
            : base(name)
        {
            _child = child;
            _maxIterations = maxIterations;
            _child.Parent = this;
        }

        public override NodeStatus Execute(float delta)
        {
            if (_currentIteration >= _maxIterations)
            {
                return NodeStatus.Success;
            }

            var status = _child.Execute(delta);
            if (status == NodeStatus.Success)
            {
                _currentIteration++;
                _child.Reset();
                return NodeStatus.Running;
            }

            return status;
        }

        public override void Reset()
        {
            _currentIteration = 0;
            _child.Reset();
        }

        public override void OnInterrupt()
        {
            _child.OnInterrupt();
        }
    }
}
