import React from 'react';
import styled from 'styled-components';
import { IconGridDots } from '@tabler/icons-react';
import { vp } from '../../../styles/scale';

const HeaderWrapper = styled.div`
  padding: ${vp(16)};
  display: flex;
  align-items: center;
  gap: ${vp(12)};
  border-bottom: ${({ theme }) => `1px solid rgba(${theme.borderColor || '44, 46, 51'}, 1)`};
`;

const HeaderIcon = styled.div`
  width: ${vp(40)};
  height: ${vp(40)};
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: ${({ theme }) => `rgb(${theme.surfaceBackground || '37, 38, 43'})`};
  border: ${({ theme }) => `1px solid rgba(${theme.borderColorSoft || '55, 58, 64'}, 1)`};
  border-radius: ${vp(8)};
  
  svg {
    color: ${({ theme }) => `rgb(${theme.accentColor || '77, 171, 247'})`};
    width: ${vp(20)};
    height: ${vp(20)};
  }
`;

const HeaderText = styled.div`
  flex: 1;
  font-family: 'Nexa-Book', sans-serif;
  
  h1 {
    font-size: ${vp(14)};
    font-weight: 600;
    color: ${({ theme }) => `rgb(${theme.fontColor || '193, 194, 197'})`};
    margin: 0 0 2px 0;
    font-family: 'Nexa-Book', sans-serif;
  }
  
  p {
    font-size: ${vp(11)};
    color: ${({ theme }) => `rgb(${theme.mutedTextColor || '144, 146, 150'})`};
    margin: 0;
    font-family: 'Nexa-Book', sans-serif;
  }
`;

interface HeaderProps {
  title?: string;
  subtitle?: string;
}

const Header: React.FC<HeaderProps> = ({ 
  title = 'Appearance Editor', 
  subtitle = 'Customize your character' 
}) => {
  return (
    <HeaderWrapper>
      <HeaderIcon>
        <IconGridDots stroke={1.5} />
      </HeaderIcon>
      <HeaderText>
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </HeaderText>
    </HeaderWrapper>
  );
};

export default Header;
