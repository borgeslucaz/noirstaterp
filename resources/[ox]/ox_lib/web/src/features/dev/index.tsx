import { ActionIcon, Button, Divider, Drawer, Select, Stack, Tooltip } from '@mantine/core';
import { debugAlert } from './debug/alert';
import { debugContext } from './debug/context';
import { debugInput } from './debug/input';
import { debugMenu } from './debug/menu';
import { debugCustomNotification } from './debug/notification';
import { debugCircleProgressbar, debugProgressbar } from './debug/progress';
import { debugTextUI } from './debug/textui';
import { debugSkillCheck } from './debug/skillcheck';
import { useState } from 'react';
import { debugRadial } from './debug/radial';
import LibIcon from '../../components/LibIcon';
import type { NotificationProps, TextUiProps } from '../../typings';

const Dev: React.FC = () => {
  const [opened, setOpened] = useState(false);
  const [notificationPosition, setNotificationPosition] = useState<NonNullable<NotificationProps['position']>>(
    'top-center'
  );
  const [textUiPosition, setTextUiPosition] = useState<NonNullable<TextUiProps['position']>>('left-center');

  return (
    <>
      <Tooltip label="Developer drawer" position="bottom">
        <ActionIcon
          onClick={() => setOpened(true)}
          radius="xl"
          variant="filled"
          color="orange"
          sx={{ position: 'absolute', bottom: 0, right: 0, width: 50, height: 50 }}
          size="xl"
          mr={50}
          mb={50}
        >
          <LibIcon icon="wrench" fontSize={24} />
        </ActionIcon>
      </Tooltip>

      <Drawer position="left" onClose={() => setOpened(false)} opened={opened} title="Developer drawer" padding="xl">
        <Stack>
          <Divider />
          <Button fullWidth onClick={() => debugInput()}>
            Open input dialog
          </Button>
          <Button fullWidth onClick={() => debugAlert()}>
            Open alert dialog
          </Button>
          <Divider />
          <Button fullWidth onClick={() => debugContext()}>
            Open context menu
          </Button>
          <Button fullWidth onClick={() => debugMenu()}>
            Open list menu
          </Button>
          <Button fullWidth onClick={() => debugRadial()}>
            Open radial menu
          </Button>
          <Divider />
          <Select
            label="Notification position"
            value={notificationPosition}
            data={['top-left', 'top-center', 'top-right', 'bottom-left', 'bottom-center', 'bottom-right']}
            onChange={(value) =>
              value && setNotificationPosition(value as NonNullable<NotificationProps['position']>)
            }
          />
          <Button fullWidth onClick={() => debugCustomNotification(notificationPosition)}>
            Send notification
          </Button>
          <Divider />
          <Button fullWidth onClick={() => debugProgressbar()}>
            Activate progress bar
          </Button>
          <Button fullWidth onClick={() => debugCircleProgressbar()}>
            Activate progress circle
          </Button>
          <Divider />
          <Select
            label="Text UI position"
            value={textUiPosition}
            data={['left-center', 'right-center', 'top-center', 'bottom-center']}
            onChange={(value) => value && setTextUiPosition(value as NonNullable<TextUiProps['position']>)}
          />
          <Button fullWidth onClick={() => debugTextUI(textUiPosition)}>
            Show TextUI
          </Button>
          <Divider />
          <Button fullWidth onClick={() => debugSkillCheck()}>
            Run skill check
          </Button>
        </Stack>
      </Drawer>
    </>
  );
};

export default Dev;
