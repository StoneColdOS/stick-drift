using UnityEngine;
using UnityEngine.UI;
using StickDrift.Car;

namespace StickDrift.UI
{
    /// <summary>Gear, speed, tach with redline, engine health, drift points, and the blown-engine screen.</summary>
    public class HudUI : MonoBehaviour
    {
        public DriftCar car;
        public Text gearText, speedText, warnText, driftText, bestText;
        public RectTransform tachFill, healthFill;
        public Image tachFillImage;
        public float tachWidth = 640f, healthWidth = 220f;
        public float tachMaxRpm = 10000f;
        public GameObject blownPanel;

        static readonly Color TachNormal = new Color(1f, 1f, 1f, 0.75f);
        static readonly Color TachHot = new Color(1f, 0.25f, 0.2f, 0.95f);

        float driftPoints, best, driftHold;

        void Update()
        {
            if (!car) return;
            var eng = car.engine;

            gearText.text = Gearbox.Label(car.Gear);
            speedText.text = Mathf.RoundToInt(car.SpeedMps * 2.237f) + " MPH";

            float rpm01 = Mathf.Clamp01(eng.Rpm / tachMaxRpm);
            tachFill.sizeDelta = new Vector2(tachWidth * rpm01, tachFill.sizeDelta.y);
            bool hot = eng.OverRedline;
            bool flash = Mathf.Repeat(Time.time * 8f, 1f) > 0.5f;
            tachFillImage.color = hot && flash ? TachHot : TachNormal;

            healthFill.sizeDelta = new Vector2(healthWidth * eng.Health, healthFill.sizeDelta.y);

            if (eng.Blown) warnText.text = "";
            else if (eng.Rpm > eng.moneyShiftRpm) warnText.text = "MONEY SHIFT!";
            else if (hot) warnText.text = flash ? "SHIFT!" : "";
            else warnText.text = "";

            blownPanel.SetActive(eng.Blown);

            // Drift points: angle x speed while sliding, banked after a short pause.
            if (car.IsDrifting && !eng.Blown)
            {
                driftPoints += Mathf.Abs(car.SlipAngle) * car.SpeedMps * Time.deltaTime * 0.6f;
                driftHold = 1.5f;
            }
            else if (driftHold > 0f)
            {
                driftHold -= Time.deltaTime;
                if (driftHold <= 0f)
                {
                    best = Mathf.Max(best, driftPoints);
                    driftPoints = 0f;
                }
            }

            driftText.text = driftPoints > 1f
                ? $"DRIFT  {Mathf.RoundToInt(driftPoints):N0}\n<size=28>{Mathf.RoundToInt(Mathf.Abs(car.SlipAngle))}°</size>"
                : "";
            bestText.text = best > 0f ? $"BEST {Mathf.RoundToInt(best):N0}" : "";
        }
    }
}
