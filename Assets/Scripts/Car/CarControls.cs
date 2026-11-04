using UnityEngine;
using StickDrift.UI;

namespace StickDrift.Car
{
    /// <summary>
    /// One place the car reads input from. The on-screen wheel, shifter and e-brake write here,
    /// and there's a keyboard fallback so you can test on the Mac:
    /// A/D or arrows = steer, 1-5 = gears, N or 0 = neutral, R = reverse, Space = e-brake.
    /// </summary>
    public class CarControls : MonoBehaviour
    {
        public ShifterUI shifter;

        public float Steer { get; private set; }
        public float Handbrake { get; private set; }
        public int Gear { get; private set; }

        [HideInInspector] public float uiSteer;
        [HideInInspector] public float uiHandbrake;

        public void SetGear(int gear) => Gear = gear;

        void Update()
        {
            float kbSteer = 0f;
            float kbHandbrake = 0f;

#if ENABLE_LEGACY_INPUT_MANAGER
            if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow)) kbSteer -= 1f;
            if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow)) kbSteer += 1f;
            if (Input.GetKey(KeyCode.Space)) kbHandbrake = 1f;

            for (int g = 1; g <= Gearbox.TopGear; g++)
                if (Input.GetKeyDown(KeyCode.Alpha0 + g)) RequestGear(g);
            if (Input.GetKeyDown(KeyCode.N) || Input.GetKeyDown(KeyCode.Alpha0)) RequestGear(Gearbox.Neutral);
            if (Input.GetKeyDown(KeyCode.R)) RequestGear(Gearbox.Reverse);
#endif

            Steer = Mathf.Abs(kbSteer) > 0f ? kbSteer : uiSteer;
            Handbrake = Mathf.Max(uiHandbrake, kbHandbrake);
        }

        void RequestGear(int gear)
        {
            if (shifter) shifter.SnapToGear(gear);
            else Gear = gear;
        }
    }
}
