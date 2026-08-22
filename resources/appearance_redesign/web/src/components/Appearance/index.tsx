import { useState, useEffect, useCallback, useMemo } from 'react';
import { useTransition as useTransitionAnimation, animated } from 'react-spring';
import { useNuiState } from '../../hooks/nuiState';
import Nui from '../../Nui';
import mock from '../../mock';

import {
  CustomizationConfig,
  PedAppearance,
  AppearanceSettings,
  PedHeadBlend,
  PedFaceFeatures,
  PedHeadOverlays,
  PedHeadOverlayValue,
  PedHair,
  CameraState,
  ClothesState,
  Tattoo,
  TattoosSettings,
} from './interfaces';

import {
  APPEARANCE_INITIAL_STATE,
  SETTINGS_INITIAL_STATE,
  CAMERA_INITIAL_STATE,
  ROTATE_INITIAL_STATE,
  CLOTHES_INITIAL_STATE,
} from './settings';

import Ped from './Ped';
import HeadBlend from './HeadBlend';
import FaceFeatures from './FaceFeatures';
import HeadOverlays from './HeadOverlays';
import Components from './Components';
import Props from './Props';
import Options from './Options';
import Modal from '../Modal';
import Tattoos from './Tattoos';

import './styles.css';

if (!import.meta.env.PROD) {
  mock('appearance_get_settings', () => ({
    appearanceSettings: {
      ...SETTINGS_INITIAL_STATE,
      eyeColor: { min: 0, max: 24 },
      hair: {
        ...SETTINGS_INITIAL_STATE.hair,
        color: {
          items: [
            [255, 0, 0],
            [0, 255, 0],
            [0, 0, 255],
            [0, 0, 255],
          ],
        },
      },
      tattoos: {
        ...SETTINGS_INITIAL_STATE.tattoos,
        items: {
          'ZONE_TORSO': [
            {
              name: 'tattoo_torso_001',
              label: 'Torso Tattoo 1',
              hashMale: 'MP_MP_ImportExport_Tat_001_M',
              hashFemale: 'MP_MP_ImportExport_Tat_001_F',
              zone: 'ZONE_TORSO',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
            {
              name: 'tattoo_torso_002',
              label: 'Torso Tattoo 2',
              hashMale: 'MP_MP_ImportExport_Tat_002_M',
              hashFemale: 'MP_MP_ImportExport_Tat_002_F',
              zone: 'ZONE_TORSO',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
            {
              name: 'tattoo_torso_003',
              label: 'Torso Tattoo 3',
              hashMale: 'MP_MP_ImportExport_Tat_003_M',
              hashFemale: 'MP_MP_ImportExport_Tat_003_F',
              zone: 'ZONE_TORSO',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
          ],
          'ZONE_HEAD': [
            {
              name: 'tattoo_head_001',
              label: 'Head Tattoo 1',
              hashMale: 'MP_MP_ImportExport_Tat_004_M',
              hashFemale: 'MP_MP_ImportExport_Tat_004_F',
              zone: 'ZONE_HEAD',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
            {
              name: 'tattoo_head_002',
              label: 'Head Tattoo 2',
              hashMale: 'MP_MP_ImportExport_Tat_005_M',
              hashFemale: 'MP_MP_ImportExport_Tat_005_F',
              zone: 'ZONE_HEAD',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
          ],
          'ZONE_LEFT_ARM': [
            {
              name: 'tattoo_left_arm_001',
              label: 'Left Arm Tattoo 1',
              hashMale: 'MP_MP_ImportExport_Tat_006_M',
              hashFemale: 'MP_MP_ImportExport_Tat_006_F',
              zone: 'ZONE_LEFT_ARM',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
            {
              name: 'tattoo_left_arm_002',
              label: 'Left Arm Tattoo 2',
              hashMale: 'MP_MP_ImportExport_Tat_007_M',
              hashFemale: 'MP_MP_ImportExport_Tat_007_F',
              zone: 'ZONE_LEFT_ARM',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
          ],
          'ZONE_RIGHT_ARM': [
            {
              name: 'tattoo_right_arm_001',
              label: 'Right Arm Tattoo 1',
              hashMale: 'MP_MP_ImportExport_Tat_008_M',
              hashFemale: 'MP_MP_ImportExport_Tat_008_F',
              zone: 'ZONE_RIGHT_ARM',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
            {
              name: 'tattoo_right_arm_002',
              label: 'Right Arm Tattoo 2',
              hashMale: 'MP_MP_ImportExport_Tat_009_M',
              hashFemale: 'MP_MP_ImportExport_Tat_009_F',
              zone: 'ZONE_RIGHT_ARM',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
          ],
          'ZONE_LEFT_LEG': [
            {
              name: 'tattoo_left_leg_001',
              label: 'Left Leg Tattoo 1',
              hashMale: 'MP_MP_ImportExport_Tat_010_M',
              hashFemale: 'MP_MP_ImportExport_Tat_010_F',
              zone: 'ZONE_LEFT_LEG',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
          ],
          'ZONE_RIGHT_LEG': [
            {
              name: 'tattoo_right_leg_001',
              label: 'Right Leg Tattoo 1',
              hashMale: 'MP_MP_ImportExport_Tat_011_M',
              hashFemale: 'MP_MP_ImportExport_Tat_011_F',
              zone: 'ZONE_RIGHT_LEG',
              collection: 'mpimportexport_overlays',
              opacity: 1.0,
            },
          ],
          'ZONE_HAIR': [
            {
              name: 'fade_001',
              label: 'Fade 1',
              hashMale: 'FM_Hair_Fuzz',
              hashFemale: 'FM_Hair_Fuzz',
              zone: 'ZONE_HAIR',
              collection: 'mp_freemode_overlays',
              opacity: 1.0,
            },
          ],
        },
      },
    },
  }));

  mock('appearance_get_data', () => ({
    config: {
      ped: true,
      headBlend: true,
      faceFeatures: true,
      headOverlays: true,
      components: true,
      componentConfig: {
        masks: true,
        upperBody: true,
        lowerBody: true,
        bags: true,
        shoes: true,
        scarfAndChains: true,
        shirts: true,
        bodyArmor: true,
        decals: true,
        jackets: true,
      },
      props: true,
      propConfig: {
        hats: true,
        glasses: true,
        ear: true,
        watches: true,
        bracelets: true,
      },
      tattoos: true,
      enableExit: true,
      hasTracker: false,
      automaticFade: false,
    },
    appearanceData: { ...APPEARANCE_INITIAL_STATE, model: 'mp_f_freemode_01' },
  }));

  mock('appearance_change_model', () => SETTINGS_INITIAL_STATE);

  mock('appearance_change_component', () => SETTINGS_INITIAL_STATE.components);

  mock('appearance_change_prop', () => SETTINGS_INITIAL_STATE.props);

  mock('appearance_get_locales', () => ({
    modal: {
      save: {
        title: 'Save',
        description: 'Do you want to save your appearance?',
      },
      exit: {
        title: 'Exit',
        description: 'Do you want to exit without saving?',
      },
      accept: 'Yes',
      decline: 'No',
    },
    ped: {
      title: 'Ped',
      model: 'Model',
    },
    headBlend: {
      title: 'Head Blend',
      shape: {
        title: 'Shape',
        firstOption: 'First Option',
        secondOption: 'Second Option',
        mix: 'Mix',
      },
      skin: {
        title: 'Skin',
        firstOption: 'First Option',
        secondOption: 'Second Option',
        mix: 'Mix',
      },
      race: {
        title: 'Race',
        shape: 'Shape',
        skin: 'Skin',
        mix: 'Mix',
      },
    },
    faceFeatures: {
      title: 'Face Features',
      nose: {
        title: 'Nose',
        width: 'Width',
        height: 'Height',
        size: 'Size',
        boneHeight: 'Bone Height',
        boneTwist: 'Bone Twist',
        peakHeight: 'Peak Height',
      },
      eyebrows: {
        title: 'Eyebrows',
        height: 'Height',
        depth: 'Depth',
      },
      cheeks: {
        title: 'Cheeks',
        boneHeight: 'Bone Height',
        boneWidth: 'Bone Width',
        width: 'Width',
      },
      eyesAndMouth: {
        title: 'Eyes and Mouth',
        eyesOpening: 'Eyes Opening',
        lipsThickness: 'Lips Thickness',
      },
      jaw: {
        title: 'Jaw',
        width: 'Width',
        size: 'Size',
      },
      chin: {
        title: 'Chin',
        lowering: 'Lowering',
        length: 'Length',
        size: 'Size',
        hole: 'Hole',
      },
      neck: {
        title: 'Neck',
        thickness: 'Thickness',
      },
    },
    headOverlays: {
      title: 'Head Overlays',
      hair: {
        title: 'Hair',
        style: 'Style',
        color: 'Color',
        highlight: 'Highlight',
        fade: 'Fade',
        texture: 'Texture',
      },
      opacity: 'Opacity',
      style: 'Style',
      color: 'Color',
      secondColor: 'Second Color',
      blemishes: 'Blemishes',
      beard: 'Beard',
      eyebrows: 'Eyebrows',
      ageing: 'Ageing',
      makeUp: 'Make Up',
      blush: 'Blush',
      complexion: 'Complexion',
      sunDamage: 'Sun Damage',
      lipstick: 'Lipstick',
      moleAndFreckles: 'Mole and Freckles',
      chestHair: 'Chest Hair',
      bodyBlemishes: 'Body Blemishes',
      eyeColor: 'Eye Color',
    },
    components: {
      title: 'Components',
      drawable: 'Drawable',
      texture: 'Texture',
      mask: 'Mask',
      upperBody: 'Upper Body',
      lowerBody: 'Lower Body',
      bags: 'Bags',
      shoes: 'Shoes',
      scarfAndChains: 'Scarf and Chains',
      shirt: 'Shirt',
      bodyArmor: 'Body Armor',
      decals: 'Decals',
      jackets: 'Jackets',
      head: 'Head',
    },
    props: {
      title: 'Props',
      drawable: 'Drawable',
      texture: 'Texture',
      hats: 'Hats',
      glasses: 'Glasses',
      ear: 'Ear',
      watches: 'Watches',
      bracelets: 'Bracelets',
    },
    tattoos: {
      title: 'Tattoos',
      items: {
        'ZONE_TORSO': 'Torso',
        'ZONE_HEAD': 'Head',
        'ZONE_LEFT_ARM': 'Left Arm',
        'ZONE_RIGHT_ARM': 'Right Arm',
        'ZONE_LEFT_LEG': 'Left Leg',
        'ZONE_RIGHT_LEG': 'Right Leg',
        'ZONE_HAIR': 'Hair',
      },
      apply: 'Apply',
      delete: 'Delete',
      deleteAll: 'Delete All',
      opacity: 'Opacity',
    },
  }));
}

interface AppearanceProps {
  selectedSection?: string | null;
  config?: CustomizationConfig;
}

const Appearance = ({ selectedSection = 'DNA', config: configProp }: AppearanceProps) => {
  const [config, setConfig] = useState<CustomizationConfig | undefined>(configProp);

  const [data, setData] = useState<PedAppearance>();
  const [storedData, setStoredData] = useState<PedAppearance>();
  const [appearanceSettings, setAppearanceSettings] = useState<AppearanceSettings>();

  const [camera, setCamera] = useState(CAMERA_INITIAL_STATE);
  const [rotate, setRotate] = useState(ROTATE_INITIAL_STATE);
  const [clothes, setClothes] = useState(CLOTHES_INITIAL_STATE);

  const [saveModal, setSaveModal] = useState(false);
  const [exitModal, setExitModal] = useState(false);

  const { display, setDisplay, locales, setLocales } = useNuiState();

  const wrapperTransition = useTransitionAnimation(display.appearance, null, {
    // from: { transform: 'translateX(-50px)', opacity: 0 },
    // enter: { transform: 'translateY(0)', opacity: 1 },
    // leave: { transform: 'translateX(-50px)', opacity: 0 },
    from: { transform: 'translateX(0)', opacity: 1 },
    enter: { transform: 'translateY(0)', opacity: 1 },
    leave: { transform: 'translateX(0)', opacity: 1 },
  });

  const saveModalTransition = useTransitionAnimation(saveModal, null, {
    from: { opacity: 0 },
    enter: { opacity: 1 },
    leave: { opacity: 0 },
  });

  const exitModalTransition = useTransitionAnimation(exitModal, null, {
    from: { opacity: 0 },
    enter: { opacity: 1 },
    leave: { opacity: 0 },
  });

  const handleTurnAround = useCallback(() => {
    Nui.post('appearance_turn_around');
  }, []);

  const handleSetClothes = useCallback(
    (key: keyof ClothesState) => {
      setClothes({ ...clothes, [key]: !clothes[key] });
      if (!clothes[key]) {
        Nui.post('appearance_remove_clothes', key);
      } else {
        Nui.post('appearance_wear_clothes', { data, key });
      }
    },
    [data, clothes, setClothes],
  );

  const handleSetCamera = useCallback(
    (key: keyof CameraState) => {
      setCamera({ ...CAMERA_INITIAL_STATE, [key]: !camera[key] });
      setRotate(ROTATE_INITIAL_STATE);

      if (!camera[key]) {
        Nui.post('appearance_set_camera', key);
      } else {
        Nui.post('appearance_set_camera', 'default');
      }
    },
    [camera, setCamera, setRotate],
  );

  const handleRotateLeft = useCallback(() => {
    setRotate({ left: !rotate.left, right: false });

    if (!rotate.left) {
      Nui.post('appearance_rotate_camera', 'left');
    } else {
      Nui.post('appearance_set_camera', 'current');
    }
  }, [setRotate, rotate]);

  const handleRotateRight = useCallback(() => {
    setRotate({ left: false, right: !rotate.right });

    if (!rotate.right) {
      Nui.post('appearance_rotate_camera', 'right');
    } else {
      Nui.post('appearance_set_camera', 'current');
    }
  }, [setRotate, rotate]);

  const handleSaveModal = useCallback(() => {
    setSaveModal(true);
  }, [setSaveModal]);

  const handleExitModal = useCallback(() => {
    setExitModal(true);
  }, [setExitModal]);

  const handleSave = useCallback(
    async (accept: boolean) => {
      if (accept) {
        await Nui.post('appearance_save', data);
        setSaveModal(false);
      } else {
        setSaveModal(false);
      }
    },
    [setSaveModal, data],
  );

  const handleExit = useCallback(
    async (accept: boolean) => {
      if (accept) {
        await Nui.post('appearance_exit');
        setExitModal(false);
      } else {
        setExitModal(false);
      }
    },
    [setExitModal],
  );

  const handleModelChange = useCallback(
    async (value: string) => {
      const { appearanceSettings: _appearanceSettings, appearanceData } = await Nui.post(
        'appearance_change_model',
        value,
      );

      setAppearanceSettings(_appearanceSettings);
      setData(appearanceData);
    },
    [setData, setAppearanceSettings],
  );

  const handleHeadBlendChange = useCallback(
    (key: keyof PedHeadBlend, value: number) => {
      if (!data) return;

      const updatedHeadBlend = { ...data.headBlend, [key]: value };

      const updatedData = { ...data, headBlend: updatedHeadBlend };

      setData(updatedData);

      Nui.post('appearance_change_head_blend', updatedHeadBlend);
    },
    [data, setData],
  );

  const handleFaceFeatureChange = useCallback(
    (key: keyof PedFaceFeatures, value: number) => {
      if (!data) return;

      const updatedFaceFeatures = { ...data.faceFeatures, [key]: value };

      const updatedData = { ...data, faceFeatures: updatedFaceFeatures };

      setData(updatedData);

      Nui.post('appearance_change_face_feature', updatedFaceFeatures);
    },
    [data, setData],
  );

  const handleHairChange = useCallback(
    async (key: keyof PedHair, value: number) => {
      if (!data || !appearanceSettings) return;

      const updatedHair = { ...data.hair, [key]: value };

      const updatedData = { ...data, hair: updatedHair };

      setData(updatedData);

      const updatedHairSettings = await Nui.post('appearance_change_hair', updatedHair);

      const updatedSettings = { ...appearanceSettings, hair: updatedHairSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const handleChangeFade = useCallback(async (value: number) => {
    if (!data || !appearanceSettings) return;
      const { tattoos } = data;
      const updatedTattoos = { ...tattoos };
      const tattoo = appearanceSettings.tattoos.items['ZONE_HAIR'][value]
      if (!updatedTattoos[tattoo.zone]) updatedTattoos[tattoo.zone] = [];
      updatedTattoos[tattoo.zone] = [tattoo];
      await Nui.post('appearance_apply_tattoo', updatedTattoos);
      setData({ ...data, tattoos: updatedTattoos });
  }, [appearanceSettings, data, setData])

  const handleHeadOverlayChange = useCallback(
    (key: keyof PedHeadOverlays, option: keyof PedHeadOverlayValue, value: number) => {
      if (!data) return;

      const updatedValue = { ...data.headOverlays[key], [option]: value };

      const updatedData = { ...data, headOverlays: { ...data.headOverlays, [key]: updatedValue } };

      setData(updatedData);

      Nui.post('appearance_change_head_overlay', { ...data.headOverlays, [key]: updatedValue });
    },
    [data, setData],
  );

  const handleEyeColorChange = useCallback(
    (value: number) => {
      if (!data) return;

      const updatedData = { ...data, eyeColor: value };

      setData(updatedData);

      Nui.post('appearance_change_eye_color', value);
    },
    [data, setData],
  );

  const handleComponentDrawableChange = useCallback(
    async (component_id: number, drawable: number) => {
      if (!data || !appearanceSettings) return;

      const component = data.components.find(c => c.component_id === component_id);

      if (!component) return;

      const updatedComponent = { ...component, drawable, texture: 0 };

      const filteredComponents = data.components.filter(c => c.component_id !== component_id);

      const updatedComponents = [...filteredComponents, updatedComponent];

      const updatedData = { ...data, components: updatedComponents };

      setData(updatedData);

      const updatedComponentSettings = await Nui.post('appearance_change_component', updatedComponent);

      const filteredComponentsSettings = appearanceSettings.components.filter(c => c.component_id !== component_id);

      const updatedComponentsSettings = [...filteredComponentsSettings, updatedComponentSettings];

      const updatedSettings = { ...appearanceSettings, components: updatedComponentsSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const handleComponentTextureChange = useCallback(
    async (component_id: number, texture: number) => {
      if (!data || !appearanceSettings) return;

      const component = data.components.find(c => c.component_id === component_id);

      if (!component) return;

      const updatedComponent = { ...component, texture };

      const filteredComponents = data.components.filter(c => c.component_id !== component_id);

      const updatedComponents = [...filteredComponents, updatedComponent];

      const updatedData = { ...data, components: updatedComponents };

      setData(updatedData);

      const updatedComponentSettings = await Nui.post('appearance_change_component', updatedComponent);

      const filteredComponentsSettings = appearanceSettings.components.filter(c => c.component_id !== component_id);

      const updatedComponentsSettings = [...filteredComponentsSettings, updatedComponentSettings];

      const updatedSettings = { ...appearanceSettings, components: updatedComponentsSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const handlePropDrawableChange = useCallback(
    async (prop_id: number, drawable: number) => {
      if (!data || !appearanceSettings) return;

      const prop = data.props.find(p => p.prop_id === prop_id);

      if (!prop) return;

      const updatedProp = { ...prop, drawable, texture: 0 };

      const filteredProps = data.props.filter(p => p.prop_id !== prop_id);

      const updatedProps = [...filteredProps, updatedProp];

      const updatedData = { ...data, props: updatedProps };

      setData(updatedData);

      const updatedPropSettings = await Nui.post('appearance_change_prop', updatedProp);

      const filteredPropsSettings = appearanceSettings.props.filter(c => c.prop_id !== prop_id);

      const updatedPropsSettings = [...filteredPropsSettings, updatedPropSettings];

      const updatedSettings = { ...appearanceSettings, props: updatedPropsSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const handlePropTextureChange = useCallback(
    async (prop_id: number, texture: number) => {
      if (!data || !appearanceSettings) return;

      const prop = data.props.find(p => p.prop_id === prop_id);

      if (!prop) return;

      const updatedProp = { ...prop, texture };

      const filteredProps = data.props.filter(p => p.prop_id !== prop_id);

      const updatedProps = [...filteredProps, updatedProp];

      const updatedData = { ...data, props: updatedProps };

      setData(updatedData);

      const updatedPropSettings = await Nui.post('appearance_change_prop', updatedProp);

      const filteredPropsSettings = appearanceSettings.props.filter(c => c.prop_id !== prop_id);

      const updatedPropsSettings = [...filteredPropsSettings, updatedPropSettings];

      const updatedSettings = { ...appearanceSettings, props: updatedPropsSettings };

      setAppearanceSettings(updatedSettings);
    },
    [data, setData, appearanceSettings, setAppearanceSettings],
  );

  const isPedFreemodeModel = useMemo(() => {
    if (!data) return;

    return data.model === 'mp_m_freemode_01' || data.model === 'mp_f_freemode_01';
  }, [data]);

  const isPedMale = useMemo(() => {
    if(!data) return;

    if (data.model === 'mp_m_freemode_01') {
      return true;
    }

    return false
  }, [data]);

  const filterTattoos = (tattooSettings: TattoosSettings) => {
    for(const zone in tattooSettings.items) {
      tattooSettings.items[zone] = tattooSettings.items[zone].filter(tattoo => {
        if(isPedMale && tattoo.hashMale !== "") {
          return tattoo;
        } else if(!isPedMale && tattoo.hashFemale !== "") {
          return tattoo;
        }
      })
    }
    return tattooSettings;
  };

  const handleApplyTattoo = useCallback(
    async (tattoo: Tattoo, opacity: number) => {
      if (!data) return;
      tattoo.opacity = opacity;
      const { tattoos } = data;
      const updatedTattoos = JSON.parse(JSON.stringify({ ...tattoos}));
      if (!updatedTattoos[tattoo.zone]) updatedTattoos[tattoo.zone] = [];
      updatedTattoos[tattoo.zone].push(tattoo);
      const applied = await Nui.post('appearance_apply_tattoo', {tattoo, updatedTattoos});
      if(applied) {
        setData({ ...data, tattoos: updatedTattoos });
      }
    },
    [data, setData],
  );

  const handlePreviewTattoo = useCallback(
    (tattoo: Tattoo, opacity: number) => {
      if (!data) return;
      tattoo.opacity = opacity;
      const { tattoos } = data;
      Nui.post('appearance_preview_tattoo', { data: tattoos, tattoo });
    },
    [data],
  );

  const handleDeleteTattoo = useCallback(
    async (tattoo: Tattoo) => {
      if (!data) return;
      const { tattoos } = data;
      const updatedTattoos = tattoos;
      // eslint-disable-next-line prettier/prettier
      updatedTattoos[tattoo.zone] = updatedTattoos[tattoo.zone].filter(tattooDelete => tattooDelete.name !== tattoo.name);
      await Nui.post('appearance_delete_tattoo', updatedTattoos);
      setData({ ...data, tattoos: updatedTattoos });
    },
    [data, setData],
  );

  const handleClearTattoos = useCallback(
    async () => {
      if (!data) return;
      const { tattoos } = data;
      const updatedTattoos = { ...tattoos };
      for (var zone in updatedTattoos) {
        if (zone !== "ZONE_HAIR") {
          updatedTattoos[zone] = [];
        }
      }
      await Nui.post('appearance_delete_tattoo', updatedTattoos);
      setData({ ...data, tattoos: updatedTattoos });
    },
    [data, setData],
  );

  useEffect(() => {
    if(!locales) {
      Nui.post('appearance_get_locales').then(result => setLocales(result));
    }

    Nui.onEvent('appearance_display', (data : any) => {
      setDisplay({ appearance: true, asynchronous: data.asynchronous });
    });

    Nui.onEvent('appearance_hide', () => {
      setDisplay({ appearance: false, asynchronous: false });
      setData(APPEARANCE_INITIAL_STATE);
      setStoredData(APPEARANCE_INITIAL_STATE);
      //setAppearanceSettings(SETTINGS_INITIAL_STATE);
      setCamera(CAMERA_INITIAL_STATE);
      setRotate(ROTATE_INITIAL_STATE);
    });
  }, []);

  const fetchData = useCallback(async () => {
    const result = await Nui.post('appearance_get_data');
    if (result) {
      if (result.config) setConfig(result.config);
      if (result.appearanceData) {
        setStoredData(result.appearanceData);
        setData(result.appearanceData);
      }
    }
  }, []);

  useEffect(() => {
    if (configProp) {
      setConfig(configProp);
    }
  }, [configProp]);

  const fetchSettings = useCallback(async () => {
    if(appearanceSettings === undefined || appearanceSettings === SETTINGS_INITIAL_STATE) {
      const result = await Nui.post('appearance_get_settings');
      setAppearanceSettings(result.appearanceSettings);
    }
  }, []);

  useEffect(() => {
    if (display.appearance) {
      if(display.asynchronous) {
        (async () => {
          await fetchSettings();
          await fetchData();
        })();
      } else {
        fetchSettings().catch(console.error);
        fetchData().catch(console.error);
      }
    }
  }, [display.appearance]);

  if (!display.appearance || !config || !appearanceSettings || !data || !storedData || !locales) {
    return null;
  }

  return (
    <>
      {wrapperTransition.map(
        ({ item, key, props: style }) =>
          item && (
            <animated.div key={key} style={style}>
              <div className="appearance-wrapper">
                <div className="appearance-container">
                  {/* Ped Section */}
                  {selectedSection === 'Ped' && config.ped && (
                    <Ped
                      settings={appearanceSettings.ped}
                      storedData={storedData.model}
                      data={data.model}
                      handleModelChange={handleModelChange}
                    />
                  )}
                  
                  {/* DNA Section - Head Blend */}
                  {selectedSection === 'DNA' && isPedFreemodeModel && config.headBlend && data && (
                    <HeadBlend
                      settings={appearanceSettings.headBlend}
                      storedData={storedData.headBlend}
                      data={data.headBlend}
                      model={data.model || 'mp_m_freemode_01'}
                      handleHeadBlendChange={handleHeadBlendChange}
                      handleModelChange={handleModelChange}
                    />
                  )}
                  
                  {/* Face Section - Face Features */}
                  {selectedSection === 'Face' && isPedFreemodeModel && config.faceFeatures && (
                    <FaceFeatures
                      settings={appearanceSettings.faceFeatures}
                      storedData={storedData.faceFeatures}
                      data={data.faceFeatures}
                      handleFaceFeatureChange={handleFaceFeatureChange}
                    />
                  )}
                  
                  {/* Hair Section - Head Overlays */}
                  {selectedSection === 'Hair' && config.headOverlays && appearanceSettings && data && storedData && (
                    <HeadOverlays
                      settings={{
                        hair: appearanceSettings.hair,
                        headOverlays: appearanceSettings.headOverlays,
                        eyeColor: appearanceSettings.eyeColor,
                        fade: appearanceSettings.tattoos?.items?.['ZONE_HAIR'] || []
                      }}
                      storedData={{
                        hair: storedData.hair,
                        headOverlays: storedData.headOverlays,
                        eyeColor: storedData.eyeColor,
                        fade: storedData.tattoos?.ZONE_HAIR?.length > 0 ? storedData.tattoos.ZONE_HAIR[0] : null
                      }}
                      data={{
                        hair: data.hair,
                        headOverlays: data.headOverlays,
                        eyeColor: data.eyeColor,
                        fade: data.tattoos?.ZONE_HAIR?.length > 0 ? data.tattoos.ZONE_HAIR[0] : null
                      }}
                      handleHairChange={handleHairChange}
                      handleHeadOverlayChange={handleHeadOverlayChange}
                      handleEyeColorChange={handleEyeColorChange}
                      handleChangeFade={handleChangeFade}
                      automaticFade={config.automaticFade}
                    />
                  )}
                  
                  {/* Clothes Section - Components */}
                  {selectedSection === 'Clothes' && config.components && (
                    <Components
                      settings={appearanceSettings.components}
                      data={data.components}
                      storedData={storedData.components}
                      handleComponentDrawableChange={handleComponentDrawableChange}
                      handleComponentTextureChange={handleComponentTextureChange}
                      componentConfig={config.componentConfig}
                      hasTracker={config.hasTracker}
                      isPedFreemodeModel={isPedFreemodeModel}
                    />
                  )}
                  
                  {/* Accessories Section - Props */}
                  {selectedSection === 'Accessories' && config.props && (
                    <Props
                      settings={appearanceSettings.props}
                      data={data.props}
                      storedData={storedData.props}
                      handlePropDrawableChange={handlePropDrawableChange}
                      handlePropTextureChange={handlePropTextureChange}
                      propConfig={config.propConfig}
                    />
                  )}
                  
                  {/* Tattoos Section */}
                  {selectedSection === 'Tattoos' && config.tattoos && appearanceSettings?.tattoos && data?.tattoos && storedData?.tattoos && (
                    <Tattoos
                      settings={appearanceSettings.tattoos}
                      data={data.tattoos}
                      storedData={storedData.tattoos}
                      handleApplyTattoo={handleApplyTattoo}
                      handlePreviewTattoo={handlePreviewTattoo}
                      handleDeleteTattoo={handleDeleteTattoo}
                      handleClearTattoos={handleClearTattoos}
                    />
                  )}
                </div>
                <Options
                  camera={camera}
                  rotate={rotate}
                  clothes={clothes}
                  handleSetClothes={handleSetClothes}
                  handleSetCamera={handleSetCamera}
                  handleTurnAround={handleTurnAround}
                  handleRotateLeft={handleRotateLeft}
                  handleRotateRight={handleRotateRight}
                  handleSave={handleSaveModal}
                  handleExit={handleExitModal}
                  enableExit={config.enableExit}
                />
              </div>
            </animated.div>
          ),
      )}
      {saveModalTransition.map(
        ({ item, key, props: style }) =>
          item && (
            <animated.div key={key} style={style}>
              <Modal
                title={locales.modal.save.title}
                description={locales.modal.save.description}
                accept={locales.modal.accept}
                decline={locales.modal.decline}
                handleAccept={() => handleSave(true)}
                handleDecline={() => handleSave(false)}
              />
            </animated.div>
          ),
      )}
      {exitModalTransition.map(
        ({ item, key, props: style }) =>
          item && (
            <animated.div key={key} style={style}>
              <Modal
                title={locales.modal.exit.title}
                description={locales.modal.exit.description}
                accept={locales.modal.accept}
                decline={locales.modal.decline}
                handleAccept={() => handleExit(true)}
                handleDecline={() => handleExit(false)}
              />
            </animated.div>
          ),
      )}
    </>
  );
};

export default Appearance;