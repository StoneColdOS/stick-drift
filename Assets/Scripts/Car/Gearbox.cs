using UnityEngine;

namespace StickDrift.Car
{
    /// <summary>
    /// 5-speed H-pattern box with ratios close to an old-school Toyota (AE86-ish).
    /// Gear numbers: -1 = reverse, 0 = neutral, 1..5 = forward gears.
    /// </summary>
    public static class Gearbox
    {
        public const int Reverse = -1;
        public const int Neutral = 0;
        public const int TopGear = 5;
        public const float ReverseRatio = 3.484f;

        static readonly float[] Forward = { 3.587f, 2.022f, 1.384f, 1.000f, 0.861f };

        public static float Ratio(int gear)
        {
            if (gear == Reverse) return -ReverseRatio;
            if (gear == Neutral) return 0f;
            return Forward[Mathf.Clamp(gear, 1, TopGear) - 1];
        }

        public static string Label(int gear)
        {
            if (gear == Reverse) return "R";
            if (gear == Neutral) return "N";
            return gear.ToString();
        }
    }
}
