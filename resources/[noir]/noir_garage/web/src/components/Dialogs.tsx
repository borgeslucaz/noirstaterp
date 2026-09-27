import React, { useEffect, useState } from "react";
import { CircleAlert, LoaderCircle } from "lucide-react";
import Modal from "./Modal";
import { GarageOption, VehicleProps, formatMoney } from "../utils/interface";
import { fetchNui } from "../utils/fetchNui";

const Spinner = () => <LoaderCircle className="spin" size={16} aria-hidden="true" />;

const FieldError: React.FC<{ id: string; message: string | null }> = ({ id, message }) => (
  message ? (
    <p id={id} className="field-error" role="alert">
      <CircleAlert size={14} aria-hidden="true" />
      {message}
    </p>
  ) : null
);

const VehicleLine: React.FC<{ vehicle: VehicleProps }> = ({ vehicle }) => (
  <p className="modal__vehicle">
    <span className="modal__vehicle-name">{vehicle.name}</span>
    <span className="plate">{vehicle.plate}</span>
  </p>
);

export const RenameDialog: React.FC<{
  vehicle: VehicleProps;
  maxLength: number;
  onDone: (name: string) => void;
  onClose: () => void;
}> = ({ vehicle, maxLength, onDone, onClose }) => {
  const [name, setName] = useState(vehicle.name);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const trimmed = name.trim();
  const invalid = !trimmed || trimmed.length > maxLength || trimmed === vehicle.name;

  const save = async () => {
    if (saving || invalid) return;
    setSaving(true);
    setError(null);
    try {
      const result = await fetchNui<string | false>('updateVehicleName', { vehicleId: vehicle.id, newName: trimmed }, { data: trimmed, delay: 500 });
      if (result) {
        onDone(result);
        return;
      }
      setError('Não foi possível salvar o apelido.');
    } catch {
      setError('Não foi possível salvar o apelido.');
    }
    setSaving(false);
  };

  return (
    <Modal
      title="Mudar apelido"
      onClose={onClose}
      closable={!saving}
      footer={(
        <>
          <button type="button" className="button" onClick={onClose} disabled={saving}>Cancelar</button>
          <button type="button" className="button button--primary" onClick={save} disabled={invalid || saving} aria-busy={saving}>
            {saving && <Spinner />}
            Salvar apelido
          </button>
        </>
      )}
    >
      <VehicleLine vehicle={vehicle} />
      <div>
        <label htmlFor="rename-input" className="field-label">Apelido</label>
        <input
          id="rename-input"
          className="field"
          data-autofocus
          type="text"
          autoComplete="off"
          maxLength={maxLength}
          value={name}
          placeholder="Carro do trampo"
          aria-invalid={!!error}
          aria-describedby="rename-hint rename-error"
          onChange={event => { setName(event.target.value); setError(null); }}
          onKeyDown={event => { if (event.key === 'Enter') save(); }}
          onFocus={event => event.target.select()}
        />
        <p id="rename-hint" className="field-hint">Modelo: {vehicle.modelLabel}. Até {maxLength} caracteres.</p>
        <FieldError id="rename-error" message={error} />
      </div>
    </Modal>
  );
};

export const TransferDialog: React.FC<{
  vehicle: VehicleProps;
  price: number;
  onDone: (target: GarageOption) => void;
  onClose: () => void;
}> = ({ vehicle, price, onDone, onClose }) => {
  const [options, setOptions] = useState<GarageOption[] | null>(null);
  const [target, setTarget] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    fetchNui<GarageOption[]>('getGarageList', { vehicleId: vehicle.id }, {
      data: [
        { value: 'pillboxgarage', label: 'Pillbox Garage Parking' },
        { value: 'sapcounsel', label: 'San Andreas Parking' },
      ],
      delay: 300,
    })
      .then(response => {
        if (!active) return;
        const list = Array.isArray(response) ? response : [];
        setOptions(list);
        if (list.length === 0) setError('Nenhuma outra garagem aceita este veículo.');
      })
      .catch(() => {
        if (!active) return;
        setOptions([]);
        setError('Não foi possível carregar as garagens.');
      });
    return () => { active = false; };
  }, [vehicle.id]);

  const selected = options?.find(option => option.value === target);

  const transfer = async () => {
    if (saving || !selected) return;
    setSaving(true);
    setError(null);
    try {
      const success = await fetchNui<boolean>('updateGarageName', { vehicleId: vehicle.id, garage: selected.value }, { data: true, delay: 500 });
      if (success) {
        onDone(selected);
        return;
      }
      setError('Não foi possível transferir o veículo.');
    } catch {
      setError('Não foi possível transferir o veículo.');
    }
    setSaving(false);
  };

  return (
    <Modal
      title="Transferir de garagem"
      onClose={onClose}
      closable={!saving}
      footer={(
        <>
          <button type="button" className="button" onClick={onClose} disabled={saving}>Cancelar</button>
          <button type="button" className="button button--primary" onClick={transfer} disabled={!selected || saving} aria-busy={saving}>
            {saving && <Spinner />}
            {price > 0 ? `Transferir por $${formatMoney(price)}` : 'Transferir veículo'}
          </button>
        </>
      )}
    >
      <VehicleLine vehicle={vehicle} />
      {options === null ? (
        <p className="loading"><Spinner /> Carregando garagens…</p>
      ) : (
        <div>
          <label htmlFor="transfer-select" className="field-label">Garagem de destino</label>
          <select
            id="transfer-select"
            className="field"
            data-autofocus
            value={target}
            disabled={saving || options.length === 0}
            aria-invalid={!!error}
            aria-describedby="transfer-hint transfer-error"
            onChange={event => { setTarget(event.target.value); setError(null); }}
          >
            <option value="" disabled>Escolha uma garagem</option>
            {options.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
          <p id="transfer-hint" className="field-hint">
            O veículo sai desta garagem e fica guardado na garagem escolhida. {price > 0 ? `Custo: $${formatMoney(price)}.` : 'Sem custo.'}
          </p>
          <FieldError id="transfer-error" message={error} />
        </div>
      )}
    </Modal>
  );
};

export const LockDialog: React.FC<{
  vehicle: VehicleProps;
  price: number;
  onDone: (success: boolean) => void;
  onClose: () => void;
}> = ({ vehicle, price, onDone, onClose }) => {
  const [busy, setBusy] = useState(false);

  const confirm = async () => {
    if (busy) return;
    setBusy(true);
    const success = await fetchNui<boolean>('lockChange', { vehicleId: vehicle.id }, { data: true, delay: 500 });
    onDone(success === true);
  };

  return (
    <Modal
      title="Trocar fechadura"
      onClose={onClose}
      closable={!busy}
      footer={(
        <>
          <button type="button" className="button" data-autofocus onClick={onClose} disabled={busy}>Cancelar</button>
          <button type="button" className="button button--primary" onClick={confirm} disabled={busy} aria-busy={busy}>
            {busy && <Spinner />}
            Confirmar
          </button>
        </>
      )}
    >
      <VehicleLine vehicle={vehicle} />
      <p>Todas as chaves deste veículo deixam de funcionar, inclusive as cópias com outras pessoas. Você recebe uma chave nova.</p>
      <p className="modal__cost">Custo: <strong className="tabular">${formatMoney(price)}</strong></p>
    </Modal>
  );
};
