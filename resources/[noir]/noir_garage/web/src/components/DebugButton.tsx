import React from "react";
import { isEnvBrowser } from "../utils/misc";
import { Button } from "@mantine/core";
import { debugData } from "../utils/debugData";
import { debugGarage, defaultVehicles } from "../debug/data";

const GarageDev: React.FC = () => {
    return isEnvBrowser() && (
        <div style={{ position: 'fixed', bottom: 20, right: 20, zIndex: 9999 }}>
            <Button
                color="dark"
                onClick={() => {
                    debugData([
                        {
                            action: 'setVisible',
                            data: {
                                visible: true,
                                vehicles: defaultVehicles,
                                garage: debugGarage,
                            }
                        }
                    ]);
                }}
            >
                Abrir garagem
            </Button>
        </div>
    );
};

export default GarageDev;
