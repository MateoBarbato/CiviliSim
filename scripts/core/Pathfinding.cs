using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace CiviliSim.Core
{
    /// <summary>
    /// Sistema de pathfinding en grid usando A*.
    /// Optimizado en C# para performance con múltiples agentes.
    /// </summary>
    public class Pathfinding
    {
        private int _gridWidth;
        private int _gridHeight;
        private bool[,] _walkableGrid;
        private readonly int _maxSteps;

        public Pathfinding(int gridWidth, int gridHeight, int maxSteps = 500)
        {
            _gridWidth = gridWidth;
            _gridHeight = gridHeight;
            _maxSteps = maxSteps;
            _walkableGrid = new bool[gridWidth, gridHeight];
            InitializeGrid();
        }

        /// <summary>
        /// Inicializa el grid asumiendo que todo es transitable.
        /// </summary>
        private void InitializeGrid()
        {
            for (int x = 0; x < _gridWidth; x++)
            {
                for (int y = 0; y < _gridHeight; y++)
                {
                    _walkableGrid[x, y] = true;
                }
            }
        }

        /// <summary>
        /// Marca una celda como no transitable.
        /// </summary>
        public void SetWalkable(int x, int y, bool walkable)
        {
            if (x >= 0 && x < _gridWidth && y >= 0 && y < _gridHeight)
            {
                _walkableGrid[x, y] = walkable;
            }
        }

        /// <summary>
        /// Verifica si una celda es transitable.
        /// </summary>
        public bool IsWalkable(int x, int y)
        {
            if (x < 0 || x >= _gridWidth || y < 0 || y >= _gridHeight)
                return false;
            return _walkableGrid[x, y];
        }

        /// <summary>
        /// Calcula el camino desde el punto de origen hasta el destino.
        /// Retorna una lista de Vector2I con las celdas del camino.
        /// Retorna null si no hay camino.
        /// </summary>
        public Vector2I[] FindPath(int startX, int startY, int endX, int endY)
        {
            if (!IsWalkable(startX, startY) || !IsWalkable(endX, endY))
                return null;

            // Si el destino es adyacente al inicio, retornar directamente
            if (Math.Abs(startX - endX) + Math.Abs(startY - endY) <= 1)
            {
                return new Vector2I[] { new Vector2I(endX, endY) };
            }

            var openSet = new HashSet<long>();
            var closedSet = new HashSet<long>();
            var gScore = new Dictionary<long, float>();
            var fScore = new Dictionary<long, float>();
            var cameFrom = new Dictionary<long, long>();
            var openPriority = new PriorityQueue<long, float>();

            long startKey = EncodeKey(startX, startY);
            long endKey = EncodeKey(endX, endY);

            openSet.Add(startKey);
            gScore[startKey] = 0f;
            fScore[startKey] = Heuristic(startX, startY, endX, endY);
            openPriority.Enqueue(startKey, fScore[startKey]);

            int steps = 0;

            while (openSet.Count > 0 && steps < _maxSteps)
            {
                steps++;
                long current = openPriority.Dequeue();
                openSet.Remove(current);

                if (current == endKey)
                {
                    return ReconstructPath(cameFrom, startKey, endKey);
                }

                closedSet.Add(current);

                int cx = DecodeX(current);
                int cy = DecodeY(current);

                // Vecinos en 4 direcciones (arriba, abajo, izquierda, derecha)
                int[] dx = { 0, 0, -1, 1 };
                int[] dy = { -1, 1, 0, 0 };

                for (int i = 0; i < 4; i++)
                {
                    int nx = cx + dx[i];
                    int ny = cy + dy[i];

                    if (!IsWalkable(nx, ny))
                        continue;

                    long neighborKey = EncodeKey(nx, ny);

                    if (closedSet.Contains(neighborKey))
                        continue;

                    float tentativeG = gScore[current] + 1.0f; // Costo uniforme en grid

                    if (!gScore.ContainsKey(neighborKey) || tentativeG < gScore[neighborKey])
                    {
                        cameFrom[neighborKey] = current;
                        gScore[neighborKey] = tentativeG;
                        fScore[neighborKey] = tentativeG + Heuristic(nx, ny, endX, endY);

                        if (!openSet.Contains(neighborKey))
                        {
                            openSet.Add(neighborKey);
                            openPriority.Enqueue(neighborKey, fScore[neighborKey]);
                        }
                    }
                }
            }

            return null; // No se encontró camino
        }

        /// <summary>
        /// Calcula un camino hacia cualquier celda dentro de un radio del destino.
        /// Útil para encontrar recursos cercanos sin necesidad de llegar exactamente al punto.
        /// </summary>
        public Vector2I[] FindPathNearTarget(int startX, int startY, int targetX, int targetY, int radius)
        {
            // Primero intentar camino directo
            var path = FindPath(startX, startY, targetX, targetY);
            if (path != null)
                return path;

            // Si no hay camino directo, buscar un punto cercano alcanzable
            var visited = new HashSet<long>();
            visited.Add(EncodeKey(startX, startY));

            for (int r = 1; r <= radius && r < _maxSteps; r++)
            {
                for (int dx = -r; dx <= r; dx++)
                {
                    for (int dy = -r; dy <= r; dy++)
                    {
                        if (Math.Abs(dx) + Math.Abs(dy) != r)
                            continue;

                        int nx = targetX + dx;
                        int ny = targetY + dy;

                        if (!IsWalkable(nx, ny))
                            continue;

                        long key = EncodeKey(nx, ny);
                        if (visited.Contains(key))
                            continue;

                        var newPath = FindPath(startX, startY, nx, ny);
                        if (newPath != null)
                            return newPath;

                        visited.Add(key);
                    }
                }
            }

            return null;
        }

        /// <summary>
        /// Reconstructs the path from cameFrom map.
        /// </summary>
        private Vector2I[] ReconstructPath(Dictionary<long, long> cameFrom, long startKey, long endKey)
        {
            var path = new List<Vector2I>();
            long current = endKey;

            while (current != startKey)
            {
                path.Add(new Vector2I(DecodeX(current), DecodeY(current)));
                if (!cameFrom.TryGetValue(current, out long previous))
                    return null;
                current = previous;
            }

            path.Reverse();
            return path.ToArray();
        }

        /// <summary>
        /// Heurística Manhattan para grid 4-direccional.
        /// </summary>
        private float Heuristic(int x1, int y1, int x2, int y2)
        {
            return Math.Abs(x1 - x2) + Math.Abs(y1 - y2);
        }

        /// <summary>
        /// Codifica coordenadas (x, y) en un único valor largo.
        /// </summary>
        private long EncodeKey(int x, int y)
        {
            return ((long)x << 32) | (uint)y;
        }

        /// <summary>
        /// Decodifica la coordenada X de una clave.
        /// </summary>
        private int DecodeX(long key)
        {
            return (int)(key >> 32);
        }

        /// <summary>
        /// Decodifica la coordenada Y de una clave.
        /// </summary>
        private int DecodeY(long key)
        {
            return (int)(key & 0xFFFFFFFFL);
        }

        /// <summary>
        /// Retorna el ancho del grid.
        /// </summary>
        public int GetGridWidth()
        {
            return _gridWidth;
        }

        /// <summary>
        /// Retorna la altura del grid.
        /// </summary>
        public int GetGridHeight()
        {
            return _gridHeight;
        }
    }
}