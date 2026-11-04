using UnityEngine;

namespace StickDrift.UI
{
    /// <summary>Keeps controls out from under the iPhone notch / Dynamic Island and home bar.</summary>
    [RequireComponent(typeof(RectTransform))]
    public class SafeArea : MonoBehaviour
    {
        RectTransform rt;
        Rect last;
        Vector2Int lastScreen;

        void Awake() => rt = (RectTransform)transform;

        void Update()
        {
            var sa = Screen.safeArea;
            var screen = new Vector2Int(Screen.width, Screen.height);
            if (sa == last && screen == lastScreen) return;
            last = sa;
            lastScreen = screen;
            if (Screen.width <= 0 || Screen.height <= 0) return;

            Vector2 min = sa.position, max = sa.position + sa.size;
            min.x /= Screen.width; max.x /= Screen.width;
            min.y /= Screen.height; max.y /= Screen.height;
            rt.anchorMin = min;
            rt.anchorMax = max;
            rt.offsetMin = rt.offsetMax = Vector2.zero;
        }
    }
}
