using System.Collections.Generic;
using UnityEngine;

namespace StickDrift.World
{
    /// <summary>Tiny low-poly meshes and primitive helpers.</summary>
    public static class MeshFactory
    {
        static Mesh prism;

        /// <summary>
        /// Flat-shaded triangular prism (a roof). Cross-section is in XY with base width 1 and height 1,
        /// base sitting on y = 0, extruded 1 unit along Z, centered on X and Z.
        /// </summary>
        public static Mesh Prism()
        {
            if (prism != null) return prism;

            Vector3 a0 = new Vector3(-0.5f, 0f, -0.5f), b0 = new Vector3(0.5f, 0f, -0.5f), c0 = new Vector3(0f, 1f, -0.5f);
            Vector3 a1 = new Vector3(-0.5f, 0f, 0.5f), b1 = new Vector3(0.5f, 0f, 0.5f), c1 = new Vector3(0f, 1f, 0.5f);
            Vector3 center = new Vector3(0f, 0.33f, 0f);

            var verts = new List<Vector3>();
            var tris = new List<int>();

            void Tri(Vector3 p, Vector3 q, Vector3 r)
            {
                Vector3 outward = (p + q + r) / 3f - center;
                if (Vector3.Dot(Vector3.Cross(q - p, r - p), outward) < 0f) (q, r) = (r, q);
                int i = verts.Count;
                verts.Add(p); verts.Add(q); verts.Add(r);
                tris.Add(i); tris.Add(i + 1); tris.Add(i + 2);
            }

            Tri(a0, c0, b0);                 // front gable
            Tri(a1, b1, c1);                 // back gable
            Tri(a0, a1, c1); Tri(a0, c1, c0); // left slope
            Tri(b0, c0, c1); Tri(b0, c1, b1); // right slope

            prism = new Mesh { name = "Prism" };
            prism.SetVertices(verts);
            prism.SetTriangles(tris, 0);
            prism.RecalculateNormals();
            prism.RecalculateBounds();
            return prism;
        }

        public static GameObject Box(Transform parent, string name, Vector3 localPos, Vector3 scale, Material mat, Quaternion? rot = null)
        {
            return Prim(PrimitiveType.Cube, parent, name, localPos, scale, mat, rot);
        }

        public static GameObject Quad(Transform parent, string name, Vector3 localPos, Quaternion rot, Vector3 scale, Material mat)
        {
            return Prim(PrimitiveType.Quad, parent, name, localPos, scale, mat, rot);
        }

        /// <summary>Flat quad lying on the ground, facing up.</summary>
        public static GameObject Decal(Transform parent, string name, Vector3 localPos, Vector2 size, Material mat, float yaw = 0f)
        {
            return Quad(parent, name, localPos, Quaternion.Euler(90f, yaw, 0f), new Vector3(size.x, size.y, 1f), mat);
        }

        public static GameObject Prim(PrimitiveType type, Transform parent, string name, Vector3 localPos, Vector3 scale, Material mat, Quaternion? rot = null)
        {
            var go = GameObject.CreatePrimitive(type);
            go.name = name;
            var col = go.GetComponent<Collider>();
            if (col) Object.Destroy(col);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = rot ?? Quaternion.identity;
            go.transform.localScale = scale;
            var r = go.GetComponent<MeshRenderer>();
            r.sharedMaterial = mat;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            r.receiveShadows = false;
            return go;
        }

        public static GameObject MeshObject(Transform parent, string name, Mesh mesh, Vector3 localPos, Quaternion rot, Vector3 scale, Material mat)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = rot;
            go.transform.localScale = scale;
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = mat;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            r.receiveShadows = false;
            return go;
        }
    }
}
