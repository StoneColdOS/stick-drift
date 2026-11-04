using System.Collections.Generic;
using UnityEngine;
using static StickDrift.World.MeshFactory;

namespace StickDrift.World
{
    public struct SpawnPoint
    {
        public Vector3 position;
        public Quaternion rotation;
    }

    /// <summary>
    /// Builds a low-poly nighttime suburb: a grid of blocks with houses and trees, streets
    /// between them, white LED street lights, and an open lot in the middle-ish to practice in.
    /// Blocks are solid (curb colliders), so the streets are your track.
    /// </summary>
    public static class NeighborhoodBuilder
    {
        public const int Blocks = 4;
        public const float BlockSize = 46f;
        public const float Road = 16f;

        public static readonly Color LedWhite = new Color(0.86f, 0.92f, 1f);
        static readonly Color Asphalt = new Color(0.10f, 0.105f, 0.12f);
        static readonly Color LotAsphalt = new Color(0.13f, 0.135f, 0.15f);
        static readonly Color Sidewalk = new Color(0.36f, 0.36f, 0.38f);
        static readonly Color Lawn = new Color(0.10f, 0.20f, 0.11f);
        static readonly Color OuterGrass = new Color(0.06f, 0.11f, 0.07f);
        static readonly Color RoofColor = new Color(0.16f, 0.15f, 0.17f);
        static readonly Color Trunk = new Color(0.22f, 0.15f, 0.10f);
        static readonly Color PoleColor = new Color(0.25f, 0.26f, 0.28f);
        static readonly Color WindowWarm = new Color(1f, 0.76f, 0.42f);
        static readonly Color Glass = new Color(0.05f, 0.07f, 0.11f);
        static readonly Color Door = new Color(0.20f, 0.12f, 0.08f);
        static readonly Color LanePaint = new Color(0.9f, 0.75f, 0.3f, 0.55f);
        static readonly Color LinePaint = new Color(1f, 1f, 1f, 0.5f);

        static readonly Color[] HouseColors =
        {
            new Color(0.62f, 0.68f, 0.74f), // pale blue
            new Color(0.74f, 0.68f, 0.56f), // beige
            new Color(0.56f, 0.64f, 0.54f), // sage
            new Color(0.58f, 0.58f, 0.60f), // gray
            new Color(0.80f, 0.77f, 0.68f), // cream
            new Color(0.62f, 0.48f, 0.44f), // brick-ish
        };

        static readonly Color[] LeafColors =
        {
            new Color(0.07f, 0.17f, 0.09f),
            new Color(0.09f, 0.20f, 0.10f),
            new Color(0.06f, 0.14f, 0.10f),
        };

        public static SpawnPoint Build(Transform parent, int seed, List<Light> lights)
        {
            var rng = new System.Random(seed);
            var root = new GameObject("Neighborhood").transform;
            root.SetParent(parent, false);

            float cell = BlockSize + Road;
            float total = Blocks * cell + Road;
            float half = total / 2f;

            Box(root, "Outer Grass", new Vector3(0f, -0.15f, 0f), new Vector3(total + 400f, 0.1f, total + 400f), MatLib.Lit(OuterGrass, 0f));
            Box(root, "Asphalt", new Vector3(0f, -0.05f, 0f), new Vector3(total, 0.1f, total), MatLib.Lit(Asphalt, 0.35f));

            var spawn = new SpawnPoint { position = Vector3.zero, rotation = Quaternion.identity };

            for (int i = 0; i < Blocks; i++)
            for (int j = 0; j < Blocks; j++)
            {
                float cx = -half + Road + BlockSize / 2f + i * cell;
                float cz = -half + Road + BlockSize / 2f + j * cell;
                var c = new Vector3(cx, 0f, cz);

                if (i == 1 && j == 1)
                {
                    BuildLot(root, c, lights);
                    spawn.position = c;
                    spawn.rotation = Quaternion.identity;
                }
                else
                {
                    BuildBlock(root, c, rng, lights);
                }
            }

            BuildLaneDashes(root, half, cell);
            BuildBoundary(root, half, rng);

            // Merge everything that doesn't move into as few draw calls as possible.
            StaticBatchingUtility.Combine(root.gameObject);
            return spawn;
        }

        // ------------------------------------------------------------------ blocks

        static void BuildBlock(Transform root, Vector3 center, System.Random rng, List<Light> lights)
        {
            var b = new GameObject("Block").transform;
            b.SetParent(root, false);
            b.localPosition = center;

            // Invisible wall around the whole block = the curb you bounce off.
            var col = b.gameObject.AddComponent<BoxCollider>();
            col.center = new Vector3(0f, 1.5f, 0f);
            col.size = new Vector3(BlockSize, 3f, BlockSize);

            Box(b, "Sidewalk", new Vector3(0f, 0.1f, 0f), new Vector3(BlockSize, 0.2f, BlockSize), MatLib.Lit(Sidewalk, 0.1f));
            Box(b, "Lawn", new Vector3(0f, 0.11f, 0f), new Vector3(BlockSize - 5f, 0.22f, BlockSize - 5f), MatLib.Lit(Lawn, 0f));

            const float lawnTop = 0.22f;
            float hx = BlockSize / 4f;
            float hz = BlockSize / 2f - 12f;
            House(b, new Vector3(-hx, lawnTop, hz), 0f, rng);
            House(b, new Vector3(hx, lawnTop, hz), 0f, rng);
            House(b, new Vector3(-hx, lawnTop, -hz), 180f, rng);
            House(b, new Vector3(hx, lawnTop, -hz), 180f, rng);

            // Trees down the side yards and a couple in the back yards.
            float sx = BlockSize / 2f - 5f;
            foreach (float side in new[] { -1f, 1f })
            for (int k = -1; k <= 1; k++)
                if (rng.NextDouble() < 0.7)
                    Tree(b, new Vector3(side * sx + Range(rng, -1f, 1f), lawnTop, k * 7f + Range(rng, -1.5f, 1.5f)), rng);
            for (int k = 0; k < 2; k++)
                if (rng.NextDouble() < 0.6)
                    Tree(b, new Vector3(Range(rng, -12f, 12f), lawnTop, Range(rng, -2f, 2f)), rng);

            // Street lights on the north and south edges, sometimes east/west too.
            float edge = BlockSize / 2f - 1.2f;
            Lamp(b, new Vector3(0f, 0.2f, edge), Vector3.forward, lights);
            Lamp(b, new Vector3(0f, 0.2f, -edge), Vector3.back, lights);
            if (rng.NextDouble() < 0.35) Lamp(b, new Vector3(edge, 0.2f, 0f), Vector3.right, lights);
            if (rng.NextDouble() < 0.35) Lamp(b, new Vector3(-edge, 0.2f, 0f), Vector3.left, lights);
        }

        static void BuildLot(Transform root, Vector3 center, List<Light> lights)
        {
            var lot = new GameObject("Practice Lot").transform;
            lot.SetParent(root, false);
            lot.localPosition = center;

            Box(lot, "Lot Asphalt", new Vector3(0f, 0.005f, 0f), new Vector3(BlockSize, 0.02f, BlockSize), MatLib.Lit(LotAsphalt, 0.4f));

            // Parking stalls along the north edge.
            var paint = MatLib.Glow(LinePaint, false);
            for (float x = -BlockSize / 2f + 4f; x <= BlockSize / 2f - 4f; x += 3f)
                Decal(lot, "Stall Line", new Vector3(x, 0.03f, BlockSize / 2f - 4f), new Vector2(0.15f, 5f), paint);

            // A painted figure-eight hint in the middle.
            var ring = MatLib.Glow(new Color(1f, 1f, 1f, 0.12f), false);
            for (int s = -1; s <= 1; s += 2)
            for (int a = 0; a < 24; a++)
            {
                float ang = a / 24f * Mathf.PI * 2f;
                var p = new Vector3(s * 9f + Mathf.Cos(ang) * 6f, 0.03f, Mathf.Sin(ang) * 6f);
                Decal(lot, "Donut Mark", p, new Vector2(0.25f, 1.2f), ring, -ang * Mathf.Rad2Deg);
            }

            float c = BlockSize / 2f - 2f;
            Lamp(lot, new Vector3(c, 0f, c), new Vector3(-1f, 0f, -1f).normalized, lights);
            Lamp(lot, new Vector3(-c, 0f, c), new Vector3(1f, 0f, -1f).normalized, lights);
            Lamp(lot, new Vector3(c, 0f, -c), new Vector3(-1f, 0f, 1f).normalized, lights);
            Lamp(lot, new Vector3(-c, 0f, -c), new Vector3(1f, 0f, 1f).normalized, lights);
        }

        // ------------------------------------------------------------------ props

        static void House(Transform parent, Vector3 pos, float yaw, System.Random rng)
        {
            var h = new GameObject("House").transform;
            h.SetParent(parent, false);
            h.localPosition = pos;
            h.localRotation = Quaternion.Euler(0f, yaw, 0f);

            float w = Range(rng, 9.5f, 12f);
            float d = Range(rng, 8f, 9.5f);
            float ht = Range(rng, 3f, 3.8f);
            Color body = HouseColors[rng.Next(HouseColors.Length)];

            Box(h, "Body", new Vector3(0f, ht / 2f, 0f), new Vector3(w, ht, d), MatLib.Lit(body, 0.05f));
            MeshObject(h, "Roof", Prism(), new Vector3(0f, ht, 0f), Quaternion.Euler(0f, 90f, 0f),
                new Vector3(d + 1f, Range(rng, 2f, 2.6f), w + 1f), MatLib.Lit(RoofColor, 0.1f));

            // Front face is local +Z. Quads face -Z by default, so flip them.
            var faceOut = Quaternion.Euler(0f, 180f, 0f);
            float fz = d / 2f + 0.02f;
            Quad(h, "Window", new Vector3(-w * 0.3f, ht * 0.55f, fz), faceOut, new Vector3(1.6f, 1.2f, 1f), WindowMat(rng));
            Quad(h, "Window", new Vector3(w * 0.3f, ht * 0.55f, fz), faceOut, new Vector3(1.6f, 1.2f, 1f), WindowMat(rng));
            Quad(h, "Door", new Vector3(w * 0.05f, 1.05f, fz), faceOut, new Vector3(1f, 2.1f, 1f), MatLib.Lit(Door, 0.2f));
            Box(h, "Porch Light", new Vector3(w * 0.05f + 0.85f, 2.2f, fz + 0.05f), new Vector3(0.18f, 0.25f, 0.12f), MatLib.Emissive(WindowWarm, 2.5f));

            // A side window, lit or not.
            float side = rng.NextDouble() < 0.5 ? -1f : 1f;
            var sideRot = Quaternion.Euler(0f, side > 0f ? -90f : 90f, 0f);
            Quad(h, "Side Window", new Vector3(side * (w / 2f + 0.02f), ht * 0.55f, 0f), sideRot, new Vector3(1.4f, 1.1f, 1f), WindowMat(rng));
        }

        static Material WindowMat(System.Random rng)
        {
            return rng.NextDouble() < 0.6 ? MatLib.Emissive(WindowWarm, 1.6f) : MatLib.Lit(Glass, 0.8f);
        }

        static void Tree(Transform parent, Vector3 pos, System.Random rng)
        {
            var t = new GameObject("Tree").transform;
            t.SetParent(parent, false);
            t.localPosition = pos;
            float s = Range(rng, 0.8f, 1.25f);
            t.localScale = Vector3.one * s;

            Box(t, "Trunk", new Vector3(0f, 1.1f, 0f), new Vector3(0.45f, 2.2f, 0.45f), MatLib.Lit(Trunk, 0f));
            var leaf = MatLib.Lit(LeafColors[rng.Next(LeafColors.Length)], 0f);
            Box(t, "Canopy", new Vector3(0f, 3.2f, 0f), new Vector3(2.8f, 2.4f, 2.8f), leaf,
                Quaternion.Euler(Range(rng, -8f, 8f), Range(rng, 0f, 90f), Range(rng, -8f, 8f)));
            Box(t, "Canopy Top", new Vector3(0f, 4.5f, 0f), new Vector3(1.9f, 1.7f, 1.9f), leaf,
                Quaternion.Euler(Range(rng, -10f, 10f), Range(rng, 0f, 90f), Range(rng, -10f, 10f)));
        }

        static void Lamp(Transform parent, Vector3 basePos, Vector3 outward, List<Light> lights, float armLen = 2.4f)
        {
            var l = new GameObject("Street Light").transform;
            l.SetParent(parent, false);
            l.localPosition = basePos;
            l.localRotation = Quaternion.LookRotation(outward, Vector3.up);

            var pole = MatLib.Lit(PoleColor, 0.4f);
            Box(l, "Pole", new Vector3(0f, 3f, 0f), new Vector3(0.2f, 6f, 0.2f), pole);
            Box(l, "Arm", new Vector3(0f, 6f, armLen / 2f), new Vector3(0.14f, 0.14f, armLen), pole);
            Box(l, "LED Head", new Vector3(0f, 5.9f, armLen), new Vector3(0.45f, 0.16f, 0.95f), MatLib.Emissive(LedWhite, 4f));

            var lightGo = new GameObject("LED Light");
            lightGo.transform.SetParent(l, false);
            lightGo.transform.localPosition = new Vector3(0f, 5.6f, armLen);
            var light = lightGo.AddComponent<Light>();
            light.type = LightType.Point;
            light.range = 19f;
            light.intensity = 2.6f;
            light.color = LedWhite;
            light.shadows = LightShadows.None;
            lights.Add(light);

            // Fake light pool on the road. Cheap, always visible, and looks great once pixelated.
            float groundY = 0.03f - basePos.y;
            var poolColor = new Color(LedWhite.r, LedWhite.g, LedWhite.b, 0.17f);
            Decal(l, "Light Pool", new Vector3(0f, groundY, armLen), new Vector2(14f, 14f), MatLib.Glow(poolColor, true));
        }

        // ------------------------------------------------------------------ roads & edges

        static void BuildLaneDashes(Transform root, float half, float cell)
        {
            var paint = MatLib.Glow(LanePaint, false);
            var parent = new GameObject("Lane Dashes").transform;
            parent.SetParent(root, false);

            for (int k = 0; k <= Blocks; k++)
            {
                float roadCenter = -half + Road / 2f + k * cell;
                for (int i = 0; i < Blocks; i++)
                {
                    float start = -half + Road + i * cell;
                    float end = start + BlockSize;
                    for (float p = start + 3f; p < end - 3f; p += 7f)
                    {
                        Decal(parent, "Dash", new Vector3(p + 1.5f, 0.02f, roadCenter), new Vector2(3f, 0.25f), paint);
                        Decal(parent, "Dash", new Vector3(roadCenter, 0.02f, p + 1.5f), new Vector2(0.25f, 3f), paint);
                    }
                }
            }
        }

        static void BuildBoundary(Transform root, float half, System.Random rng)
        {
            var edges = new GameObject("Boundary").transform;
            edges.SetParent(root, false);

            void Wall(Vector3 pos, Vector3 size)
            {
                var w = new GameObject("Wall");
                w.transform.SetParent(edges, false);
                w.transform.localPosition = pos;
                var c = w.AddComponent<BoxCollider>();
                c.size = size;
            }

            float t = 2f, len = half * 2f + 4f;
            Wall(new Vector3(0f, 2f, half + 1f), new Vector3(len, 4f, t));
            Wall(new Vector3(0f, 2f, -half - 1f), new Vector3(len, 4f, t));
            Wall(new Vector3(half + 1f, 2f, 0f), new Vector3(t, 4f, len));
            Wall(new Vector3(-half - 1f, 2f, 0f), new Vector3(t, 4f, len));

            // Dark treeline outside the map.
            for (float p = -half - 10f; p <= half + 10f; p += 6f)
            {
                Tree(edges, new Vector3(p + Range(rng, -2f, 2f), 0f, half + Range(rng, 4f, 14f)), rng);
                Tree(edges, new Vector3(p + Range(rng, -2f, 2f), 0f, -half - Range(rng, 4f, 14f)), rng);
                Tree(edges, new Vector3(half + Range(rng, 4f, 14f), 0f, p + Range(rng, -2f, 2f)), rng);
                Tree(edges, new Vector3(-half - Range(rng, 4f, 14f), 0f, p + Range(rng, -2f, 2f)), rng);
            }
        }

        static float Range(System.Random rng, float min, float max) => min + (float)rng.NextDouble() * (max - min);
    }
}
