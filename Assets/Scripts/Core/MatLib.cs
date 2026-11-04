using System.Collections.Generic;
using UnityEngine;

namespace StickDrift
{
    /// <summary>
    /// Makes and caches materials at runtime. Uses template materials saved by the editor setup
    /// so the shaders are guaranteed to be included in iPhone builds. Cached per color so the
    /// static batcher can merge the neighborhood into a handful of draw calls.
    /// </summary>
    public static class MatLib
    {
        static Material lit, emissive, glow;
        static readonly Dictionary<string, Material> Cache = new Dictionary<string, Material>();
        static Texture2D softCircle;

        public static void Init(Material litTemplate, Material emissiveTemplate, Material glowTemplate)
        {
            Cache.Clear();

            lit = litTemplate;
            if (lit == null)
            {
                // Fallback: borrow the default primitive material (Standard).
                var tmp = GameObject.CreatePrimitive(PrimitiveType.Cube);
                lit = new Material(tmp.GetComponent<Renderer>().sharedMaterial);
                Object.Destroy(tmp);
            }

            emissive = emissiveTemplate;
            if (emissive == null)
            {
                emissive = new Material(lit);
                emissive.EnableKeyword("_EMISSION");
            }

            glow = glowTemplate;
            if (glow == null)
            {
                var shader = Shader.Find("Sprites/Default");
                glow = shader != null ? new Material(shader) : new Material(lit);
            }
        }

        public static Material Lit(Color c, float smoothness = 0.2f)
        {
            string key = "L" + c + smoothness;
            if (Cache.TryGetValue(key, out var m)) return m;
            m = new Material(lit) { color = c };
            m.SetFloat("_Glossiness", smoothness);
            m.SetFloat("_Metallic", 0f);
            Cache[key] = m;
            return m;
        }

        public static Material Emissive(Color c, float intensity)
        {
            string key = "E" + c + intensity;
            if (Cache.TryGetValue(key, out var m)) return m;
            m = EmissiveInstance(c, intensity);
            Cache[key] = m;
            return m;
        }

        /// <summary>Uncached, for things that change brightness at runtime (brake lights).</summary>
        public static Material EmissiveInstance(Color c, float intensity)
        {
            var m = new Material(emissive) { color = c * 0.5f };
            m.EnableKeyword("_EMISSION");
            m.SetColor("_EmissionColor", c * intensity);
            return m;
        }

        /// <summary>Unlit, alpha-blended. Used for light pools, road paint, smoke, skid marks.</summary>
        public static Material Glow(Color c, bool soft)
        {
            string key = "G" + c + soft;
            if (Cache.TryGetValue(key, out var m)) return m;
            m = new Material(glow) { color = c };
            if (soft) m.mainTexture = SoftCircle();
            Cache[key] = m;
            return m;
        }

        public static Texture2D SoftCircle()
        {
            if (softCircle != null) return softCircle;
            const int size = 64;
            softCircle = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear
            };
            var px = new Color[size * size];
            float r = size / 2f;
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(r, r)) / r;
                float a = Mathf.Clamp01(1f - d);
                px[y * size + x] = new Color(1f, 1f, 1f, a * a);
            }
            softCircle.SetPixels(px);
            softCircle.Apply();
            return softCircle;
        }
    }
}
