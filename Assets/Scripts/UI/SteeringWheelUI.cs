using UnityEngine;
using UnityEngine.EventSystems;
using StickDrift.Car;

namespace StickDrift.UI
{
    /// <summary>
    /// Touch steering wheel. Put your thumb anywhere on it and twist around the center.
    /// Let go and it spins back to center on its own, like letting the wheel slip through your hands mid-drift.
    /// </summary>
    public class SteeringWheelUI : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        public CarControls controls;
        public RectTransform wheel;
        [Tooltip("How far the on-screen wheel turns for full lock, in degrees each way.")]
        public float maxWheelAngle = 150f;
        [Tooltip("Self-centering speed when you let go, degrees per second.")]
        public float returnSpeed = 600f;
        [Tooltip("Ignore touches this close to the center (fraction of radius), angles get jumpy there.")]
        public float deadZone = 0.18f;

        float angle;
        bool held;
        int pointerId;
        float lastPointerAngle;
        RectTransform rt;

        void Awake() => rt = (RectTransform)transform;

        bool PointerAngle(PointerEventData e, out float a)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(rt, e.position, e.pressEventCamera, out var local);
            a = Mathf.Atan2(local.y, local.x) * Mathf.Rad2Deg;
            return local.magnitude > deadZone * rt.rect.width * 0.5f;
        }

        public void OnPointerDown(PointerEventData e)
        {
            if (held) return;
            held = true;
            pointerId = e.pointerId;
            PointerAngle(e, out lastPointerAngle);
        }

        public void OnDrag(PointerEventData e)
        {
            if (!held || e.pointerId != pointerId) return;
            bool valid = PointerAngle(e, out float a);
            if (valid) angle = Mathf.Clamp(angle + Mathf.DeltaAngle(lastPointerAngle, a), -maxWheelAngle, maxWheelAngle);
            lastPointerAngle = a;
        }

        public void OnPointerUp(PointerEventData e)
        {
            if (e.pointerId == pointerId) held = false;
        }

        void Update()
        {
            if (!held) angle = Mathf.MoveTowards(angle, 0f, returnSpeed * Time.deltaTime);
            if (wheel) wheel.localEulerAngles = new Vector3(0f, 0f, angle);
            // UI rotation is counter-clockwise positive (left turn); car steer is right-positive.
            if (controls) controls.uiSteer = -angle / maxWheelAngle;
        }
    }
}
