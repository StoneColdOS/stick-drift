using UnityEngine;

namespace StickDrift.UI
{
    /// <summary>Procedurally drawn circles and rings so the project needs no image assets yet.</summary>
    public static class ShapeSprites
    {
        static Sprite circle, ring, thinRing;

        public static Sprite Circle => circle ? circle : circle = Make(256, 0f);
        public static Sprite Ring => ring ? ring : ring = Make(512, 0.17f);
        public static Sprite ThinRing => thinRing ? thinRing : thinRing = Make(256, 0.06f);

        /// <param name="thickness">0 = filled disc, otherwise ring thickness as a fraction of the radius.</param>
        static Sprite Make(int size, float thickness)
        {
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear
            };
            var px = new Color[size * size];
            float r = size / 2f;
            float aa = 1.5f / r;
            float inner = thickness > 0f ? 1f - thickness : -1f;

            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(r, r)) / r;
                float outerA = Mathf.Clamp01((1f - aa - d) / aa);
                float innerA = inner < 0f ? 1f : Mathf.Clamp01((d - inner) / aa);
                px[y * size + x] = new Color(1f, 1f, 1f, outerA * innerA);
            }

            tex.SetPixels(px);
            tex.Apply();
            return Sprite.Create(tex, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100f);
        }
    }
}
