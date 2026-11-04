using UnityEngine;
using UnityEngine.EventSystems;
using StickDrift.Car;

namespace StickDrift.UI
{
    /// <summary>
    /// H-pattern stick shift. The knob is locked to the gate, so going from 2nd to 3rd it travels
    /// down-to-neutral, across, then up, like a real shifter. You can drag diagonally and it'll
    /// follow the gate for you.
    ///
    ///   1   3   5
    ///   |   |   |
    ///   +---N---+
    ///   |   |   |
    ///   2   4   R
    ///
    /// Gate coordinates: columns at x = -1, 0, 1; neutral row at y = 0; gears at y = +1 / -1.
    /// </summary>
    public class ShifterUI : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        public CarControls controls;
        public RectTransform knob;
        [Tooltip("Pixels per gate unit.")]
        public float unit = 120f;
        [Tooltip("How far into a slot (0..1) before the gear engages.")]
        public float engageThreshold = 0.72f;
        [Tooltip("Gate units per second the knob can travel while you drag.")]
        public float followSpeed = 30f;
        public float settleSpeed = 9f;

        public int CurrentGear { get; private set; }

        Vector2 pos;          // knob position in gate units
        Vector2 dragTarget;
        Vector2 settleTarget;
        Vector2 grabOffset;
        bool held;
        int pointerId;
        RectTransform rt;

        void Awake() => rt = (RectTransform)transform;

        public static int GearAt(Vector2 slot)
        {
            int col = Mathf.RoundToInt(slot.x);
            bool up = slot.y > 0f;
            switch (col)
            {
                case -1: return up ? 1 : 2;
                case 0: return up ? 3 : 4;
                default: return up ? 5 : Gearbox.Reverse;
            }
        }

        public static Vector2 SlotFor(int gear)
        {
            switch (gear)
            {
                case 1: return new Vector2(-1f, 1f);
                case 2: return new Vector2(-1f, -1f);
                case 3: return new Vector2(0f, 1f);
                case 4: return new Vector2(0f, -1f);
                case 5: return new Vector2(1f, 1f);
                case Gearbox.Reverse: return new Vector2(1f, -1f);
                default: return Vector2.zero;
            }
        }

        Vector2 ToUnits(PointerEventData e)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(rt, e.position, e.pressEventCamera, out var local);
            return local / unit;
        }

        public void OnPointerDown(PointerEventData e)
        {
            if (held) return;
            held = true;
            pointerId = e.pointerId;
            grabOffset = pos - ToUnits(e);
            dragTarget = pos;
        }

        public void OnDrag(PointerEventData e)
        {
            if (!held || e.pointerId != pointerId) return;
            dragTarget = ProjectToGate(ToUnits(e) + grabOffset);
        }

        public void OnPointerUp(PointerEventData e)
        {
            if (e.pointerId != pointerId) return;
            held = false;
            // Released far enough into a slot: seat it. Otherwise spring back to neutral (center).
            settleTarget = Mathf.Abs(pos.y) >= engageThreshold
                ? new Vector2(Mathf.Round(pos.x), Mathf.Sign(pos.y))
                : Vector2.zero;
        }

        /// <summary>Used by the keyboard fallback.</summary>
        public void SnapToGear(int gear)
        {
            held = false;
            pos = settleTarget = dragTarget = SlotFor(gear);
            ApplyGear();
        }

        void Update()
        {
            Vector2 target = held ? dragTarget : settleTarget;
            pos = MoveAlongGate(pos, target, (held ? followSpeed : settleSpeed) * Time.deltaTime);
            ApplyGear();
            if (knob) knob.anchoredPosition = pos * unit;
        }

        void ApplyGear()
        {
            int g = Mathf.Abs(pos.y) >= engageThreshold ? GearAt(pos) : Gearbox.Neutral;
            if (g == CurrentGear) return;
            CurrentGear = g;
            if (controls) controls.SetGear(g);
        }

        /// <summary>Nearest point on the gate (the neutral row or one of the three columns).</summary>
        static Vector2 ProjectToGate(Vector2 p)
        {
            var best = new Vector2(Mathf.Clamp(p.x, -1f, 1f), 0f);
            float bestD = (p - best).sqrMagnitude;
            for (int c = -1; c <= 1; c++)
            {
                var q = new Vector2(c, Mathf.Clamp(p.y, -1f, 1f));
                float d = (p - q).sqrMagnitude;
                if (d < bestD) { bestD = d; best = q; }
            }
            return best;
        }

        /// <summary>Move along the gate toward a target without cutting across it.</summary>
        static Vector2 MoveAlongGate(Vector2 cur, Vector2 tgt, float dist)
        {
            for (int i = 0; i < 4 && dist > 0f; i++)
            {
                Vector2 wp = NextWaypoint(cur, tgt);
                float len = Vector2.Distance(cur, wp);
                if (len <= dist)
                {
                    cur = wp;
                    dist -= len;
                    if ((cur - tgt).sqrMagnitude < 1e-6f) return tgt;
                }
                else
                {
                    return Vector2.MoveTowards(cur, wp, dist);
                }
            }
            return cur;
        }

        static Vector2 NextWaypoint(Vector2 cur, Vector2 tgt)
        {
            const float e = 1e-3f;
            if (Mathf.Abs(cur.x - tgt.x) < e) return tgt;             // same column (or both on the row)
            if (Mathf.Abs(cur.y) > e) return new Vector2(cur.x, 0f);  // first drop back to neutral
            if (Mathf.Abs(tgt.y) <= e) return tgt;                    // slide along the neutral row
            return new Vector2(tgt.x, 0f);                            // line up under the target column
        }
    }
}
