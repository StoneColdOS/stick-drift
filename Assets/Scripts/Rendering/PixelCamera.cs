using UnityEngine;
using UnityEngine.UI;

namespace StickDrift.Rendering
{
    /// <summary>
    /// Renders the world into a tiny render texture with point filtering and shows it full screen,
    /// which gives the chunky pixelated look. Lower targetHeight = chunkier pixels.
    /// </summary>
    [RequireComponent(typeof(Camera))]
    public class PixelCamera : MonoBehaviour
    {
        public RawImage output;
        [Range(120, 720)] public int targetHeight = 270;

        Camera cam;
        RenderTexture rt;
        int lastW, lastH, lastTarget;

        void Awake() => cam = GetComponent<Camera>();

        void Update()
        {
            if (Screen.width == lastW && Screen.height == lastH && targetHeight == lastTarget && rt != null) return;
            lastW = Screen.width;
            lastH = Screen.height;
            lastTarget = targetHeight;
            Rebuild();
        }

        void Rebuild()
        {
            if (rt != null)
            {
                cam.targetTexture = null;
                rt.Release();
                Destroy(rt);
            }

            int h = targetHeight;
            int w = Mathf.Max(1, Mathf.RoundToInt(h * (float)Screen.width / Mathf.Max(1, Screen.height)));
            rt = new RenderTexture(w, h, 24)
            {
                filterMode = FilterMode.Point,
                antiAliasing = 1,
                name = "Pixel World"
            };
            rt.Create();
            cam.targetTexture = rt;
            if (output) output.texture = rt;
        }

        void OnDestroy()
        {
            if (rt != null) rt.Release();
        }
    }
}
