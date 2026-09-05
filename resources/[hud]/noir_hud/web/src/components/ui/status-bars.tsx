import { useMemo } from "react";
import { TiHeartFullOutline } from "react-icons/ti";

interface StatBarProps extends React.HTMLAttributes<HTMLDivElement> {
  Icon?: React.ComponentType<{ className?: string; "aria-hidden"?: boolean }>;
  value?: number;
  maxValue?: number;
  color?: string;
  vertical?: boolean;
  iconColor?: string;
}

export const StatBar = ({ Icon = TiHeartFullOutline, value = 20, maxValue = 100, color = "#F2F2F2", vertical = false, iconColor, "aria-label": ariaLabel, ...props }: StatBarProps) => {
  const percentage = useMemo(() => Math.min(100, Math.max(0, (value / maxValue) * 100)), [value, maxValue]);
  const finalIconColor = value === 0 ? "text-red-500" : iconColor || "text-y_white";
  return (
    <div className={`flex ${vertical ? "h-[3dvh] gap-1 4k:gap-2" : "status-bar-row w-full"} items-center`} {...props}>
      {!vertical && <Icon className={`${finalIconColor} status-bar-icon`} aria-hidden={true} />}
      {!vertical && <span className="status-bar-value">{Math.round(value)}</span>}
      <div
        className={`relative ${vertical ? "drop-shadow-[0_1.2px_1.2px_rgba(0,0,0,1)] h-full 2k:w-[6px] w-[4px] 4k:w-[8px] rounded-full bg-black/30 overflow-hidden" : "status-bar-track"}`}
        {...(!vertical ? {
          role: "progressbar",
          "aria-valuemin": 0,
          "aria-valuemax": maxValue,
          "aria-valuenow": Math.round(value),
          "aria-label": ariaLabel,
        } : undefined)}
      >
        <div
          className={`absolute ${vertical ? "bottom-0 w-full rounded-[1px] transition-all ease-in-out" : "status-bar-fill"}`}
          style={{
            backgroundColor: color,
            [vertical ? "height" : "width"]: `${percentage}%`,
            ...(vertical ? {
              borderRadius: percentage < 100 ? "50px" : "9999px",
              overflow: "hidden",
            } : undefined),
          }}
        />
      </div>
      {vertical && <Icon className={`${finalIconColor} drop-shadow-[0_1.2px_1.2px_rgba(0,0,0,1)] text-[0.8vw]`} aria-hidden={true} />}
    </div>
  );
};

interface StatBarSegmentedProps extends React.HTMLAttributes<HTMLDivElement> {
  Icon?: React.ComponentType<{ className?: string }>;
  value?: number;
  color?: string;
}

export const StatBarSegmented = ({ Icon = TiHeartFullOutline, value = 20, color = "#F2F2F2", ...props }: StatBarSegmentedProps) => {
  const segments = 4;
  const segmentWidth = 100 / segments;

  const segmentFills = useMemo(
    () =>
      Array.from({ length: segments }, (_, i) => {
        const segmentMaxValue = ((i + 1) * 100) / segments;
        if (value >= segmentMaxValue) {
          return 100;
        } else if (value > (i * 100) / segments) {
          return ((value - (i * 100) / segments) / segmentWidth) * 100;
        } else {
          return 0;
        }
      }),
    [value, segments, segmentWidth],
  );

  return (
    <div className="flex items-center gap-1 w-full 4k:gap-2" {...props}>
      <Icon className="text-y_white text-[1vw] drop-shadow-[0_1.2px_1.2px_rgba(0,0,0,1)]" />
      <p className="text-[0.6vw] drop-shadow-[0_1.2px_1.2px_rgba(0,0,0,1)] w-[20px] 4k:text-base 2k:text-sm text-center font-bold" style={{ color: color }}>
        {value}
      </p>
      <div className="relative flex gap-3 *:drop-shadow-[0_1.2px_1.2px_rgba(0,0,0,1)] w-full ml-1 h-[8px] 2k:h-3 rounded-[1px]">
        {segmentFills.map((fill, index) => (
          <svg key={index} width="100%" height="100%" className={"rounded-full "} viewBox="0 0 100 24" preserveAspectRatio="none">
            <rect x="0" y="0" width="100" height="24" className={"fill-black/30"} />
            <rect x="0" y="0" width={fill} height="24" fill={color} className={"transition-all"} />
          </svg>
        ))}
      </div>
    </div>
  );
};
