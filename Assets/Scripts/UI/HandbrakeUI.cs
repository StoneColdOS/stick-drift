using UnityEngine;
using UnityEngine.EventSystems;
using StickDrift.Car;

namespace StickDrift.UI
{
    /// <summary>Hydraulic-style e-brake lever. Grab it and pull down; it springs back when you let go.</summary>
    public class HandbrakeUI : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        public CarControls controls;
        public RectTransform handle;
        public float topY = 140f;
        public float travel = 240f;
        public float returnSpeed = 7f;

        float value;
        float startValue;
        float startY;
        bool held;
        int pointerId;
        RectTransform rt;

        void Awake() => rt = (RectTransform)transform;

        float LocalY(PointerEventData e)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(rt, e.position, e.pressEventCamera, out var local);
            return local.y;
        }

        public void OnPointerDown(PointerEventData e)
        {
            if (held) return;
            held = true;
            pointerId = e.pointerId;
            startY = LocalY(e);
            startValue = value;
        }

        public void OnDrag(PointerEventData e)
        {
            if (!held || e.pointerId != pointerId) return;
            value = Mathf.Clamp01(startValue + (startY - LocalY(e)) / travel);
        }

        public void OnPointerUp(PointerEventData e)
        {
            if (e.pointerId == pointerId) held = false;
        }

        void Update()
        {
            if (!held) value = Mathf.MoveTowards(value, 0f, returnSpeed * Time.deltaTime);
            if (handle) handle.anchoredPosition = new Vector2(0f, topY - value * travel);
            if (controls) controls.uiHandbrake = value;
        }
    }
}
