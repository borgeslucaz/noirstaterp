import { useState, useEffect, useRef, ReactNode, useMemo } from 'react';
import { FiChevronDown, FiChevronUp } from 'react-icons/fi';
import { useSpring, animated } from 'react-spring';
import './Section.css';

interface SectionProps {
  title: string;
  deps?: any[];
  children?: ReactNode;
}

const Section: React.FC<SectionProps> = ({ children, title, deps = [] }) => {
  const [active, setActive] = useState(false);

  const [height, setHeight] = useState(0);
  const ref = useRef<HTMLDivElement>(null);

  const props = useSpring({
    height: active ? height : 0,
    opacity: active ? 1 : 0,
    config: { tension: 300, friction: 30 },
  });

  useEffect(() => {
    if (ref.current) {
      const updateHeight = () => {
        if (ref.current) {
          const newHeight = ref.current.offsetHeight;
          setHeight(prevHeight => {
            if (newHeight !== prevHeight) {
              return newHeight;
            }
            return prevHeight;
          });
        }
      };
      
      updateHeight();
      
      // ResizeObserver veya MutationObserver kullanabiliriz ama şimdilik sadece deps değiştiğinde güncelle
      const timeoutId = setTimeout(updateHeight, 0);
      return () => clearTimeout(timeoutId);
    }
  }, [deps, active]);

  return (
    <div className="section-container">
      <div 
        className={`section-header ${active ? 'active' : ''}`}
        onClick={() => setActive(state => !state)}
        style={{ background: active ? 'rgba(0, 0, 0, 1)' : 'rgba(0, 0, 0, 0.7)' }}
      >
        <span>{title}</span>
        {active ? <FiChevronUp size={30} /> : <FiChevronDown size={30} />}
      </div>

      <animated.div style={{ ...props, overflow: 'hidden' } as any}>
        <div className="section-items" ref={ref}>{children}</div>
      </animated.div>
    </div>
  );
};

export default Section;
